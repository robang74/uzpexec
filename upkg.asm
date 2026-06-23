; ==============================================================================
; upkg.asm - Micro pipe executor with gzip self-extraction (Phase 1: 1024 bytes)
; (C) 2026, based on upexec by Roberto A. Foglietta, MIT license
; ==============================================================================
; Architecture: First-Read Discard (1024 bytes). The binary MUST be padded
; to exactly 1024 bytes. The gzip payload is appended starting at byte 1024.
; Compatible with: gzip -1 (fixed Huffman), stored blocks, pigz --fixed
; NOT yet compatible with: gzip -9 dynamic Huffman (BTYPE=10)
; ==============================================================================

BITS 32
org 0x08048000

; ==============================================================================
; ELF32 HEADER + PHDR
; ==============================================================================
elf_header:
  db 0x7F, 'ELF', 1, 1, 1, 0
  times 8 db 0
  dw 2
  dw 3
  dd 1
  dd code_start
  dd phdr - elf_header
  dd 0
  dd 0
  dw 52
  dw 32
  dw 1
  dw 0, 0, 0

phdr:
  dd 1
  dd 0
  dd 0x08048000
  dd 0x08048000
  dd file_end - elf_header
  dd bss_end - elf_header
  dd 7
  dd 0x1000

; ==============================================================================
; BOOTSTRAP I/O + FIRST READ DISCARD
; ==============================================================================
code_start:
  pop eax
  mov esi, esp
  lea ebp, [esp+eax*4+4]
  mov [saved_argv], esi
  mov [saved_envp], ebp

  ; Open argv[0] or use stdin
  mov ebx, [esi]
  test ebx, ebx
  jz .stdin
  cmp byte [ebx], 0
  jz .stdin
  xor ecx, ecx
  mov eax, 5
  int 0x80
  test eax, eax
  js exit_error
  mov edi, eax
  jmp .memfd
.stdin:
  xor edi, edi

.memfd:
  mov eax, 356
  mov ebx, pkgname
  push 1
  pop ecx
  int 0x80
  test eax, eax
  js exit_error
  mov [memfd], eax

  ; First read discard: read exactly 1024 bytes and drop them
  mov ecx, buf
  mov edx, 1024
.discard:
  mov eax, 3
  mov ebx, edi
  int 0x80
  test eax, eax
  js exit_error
  jz .decompress
  sub edx, eax
  jnz .discard

.decompress:
  call parse_gzip_header
  call deflate_loop

  ; ==============================================================================
  ; EXECVEAT
  ; ==============================================================================
.do_exec:
  mov eax, [saved_argv]
  mov [eax], ebx
  mov eax, 358
  mov ebx, [memfd]
  push 0
  mov ecx, esp
  mov edx, [saved_argv]
  mov esi, [saved_envp]
  mov edi, 0x1000
  int 0x80

exit_error:
  push 1
  pop eax
  xor ebx, ebx
  inc ebx
  int 0x80

; ==============================================================================
; GZIP HEADER PARSER
; ==============================================================================
parse_gzip_header:
  call get_byte
  cmp al, 0x1F
  jne exit_error
  call get_byte
  cmp al, 0x8B
  jne exit_error
  call get_byte
  cmp al, 8
  jne exit_error
  call get_byte
  mov [flags], al
  mov cl, 6
.skip6:
  call get_byte
  dec cl
  jnz .skip6
  test byte [flags], 4
  jz .no_extra
  call get_byte
  movzx ecx, al
  call get_byte
  shl ecx, 8
  or cl, al
.skip_extra:
  call get_byte
  loop .skip_extra
.no_extra:
  test byte [flags], 8
  jz .no_name
.skip_name:
  call get_byte
  test al, al
  jnz .skip_name
.no_name:
  test byte [flags], 16
  jz .no_comment
.skip_comment:
  call get_byte
  test al, al
  jnz .skip_comment
.no_comment:
  test byte [flags], 2
  jz .no_crc
  call get_byte
  call get_byte
.no_crc:
  ret

; ==============================================================================
; BIT STREAM READER
; ==============================================================================
get_byte:
  push ebx
  push edx
  mov ecx, [in_ptr]
  cmp ecx, [in_end]
  jb .ok
  mov eax, 3
  mov ebx, edi
  mov ecx, buf
  mov edx, 1024
  int 0x80
  test eax, eax
  js exit_error
  jz .eof
  mov [in_ptr], buf
  add eax, buf
  mov [in_end], eax
  mov ecx, buf
.ok:
  mov al, [ecx]
  inc dword [in_ptr]
  pop edx
  pop ebx
  ret
.eof:
  pop edx
  pop ebx
  jmp exit_error

get_bit:
  test byte [nbits], 0xFF
  jnz .has
  call get_byte
  mov [bit_buf], al
  mov byte [nbits], 8
.has:
  mov al, [bit_buf]
  shr al, 1
  mov [bit_buf], al
  dec byte [nbits]
  ret

get_n_bits:
  push ecx
  xor eax, eax
.loop:
  push ecx
  call get_bit
  pop ecx
  rcl eax, 1
  dec cl
  jnz .loop
  pop ecx
  ret

; ==============================================================================
; DEFLATE DECODER
; ==============================================================================
deflate_loop:
  mov cl, 1
  call get_n_bits
  mov [bfinal], al
  mov cl, 2
  call get_n_bits
  test al, al
  jz stored_block
  dec al
  jz fixed_block
  jmp exit_error

check_final:
  test byte [bfinal], 1
  jz deflate_loop
  ret

; ------------------------------------------------------------------------------
; STORED BLOCK (BTYPE=00)
; ------------------------------------------------------------------------------
stored_block:
  mov byte [nbits], 0
  call get_byte
  mov cl, al
  call get_byte
  mov ch, al
  call get_byte
  call get_byte
.copy_stored:
  call get_byte
  mov [buf], al
  push ecx
  push 4
  pop eax
  mov ebx, [memfd]
  mov ecx, buf
  mov edx, 1
  int 0x80
  pop ecx
  dec cx
  jnz .copy_stored
  jmp check_final

; ------------------------------------------------------------------------------
; FIXED HUFFMAN BLOCK (BTYPE=01)
; ------------------------------------------------------------------------------
fixed_block:
  call decode_fixed
  cmp ax, 256
  je .end_block
  jb .literal
  sub ax, 257
  movzx eax, ax
  call decode_length
  push eax
  mov cl, 5
  call get_n_bits
  mov ebx, eax
  mov cl, 5
  call bitrev
  call decode_distance
  pop ecx
  call copy_match
  jmp fixed_block
.literal:
  mov [buf], al
  pusha
  push 4
  pop eax
  mov ebx, [memfd]
  mov ecx, buf
  mov edx, 1
  int 0x80
  popa
  jmp fixed_block
.end_block:
  jmp check_final

; ------------------------------------------------------------------------------
; FIXED HUFFMAN SYMBOL DECODER
; ------------------------------------------------------------------------------
decode_fixed:
  mov cl, 7
  call get_n_bits
  mov ebx, eax
  mov cl, 7
  call bitrev
  cmp al, 23
  ja .not7
  add eax, 256
  ret
.not7:
  mov cl, 1
  call get_n_bits
  shl eax, 7
  or ebx, eax
  mov eax, ebx
  mov cl, 8
  call bitrev
  cmp al, 0x30
  jb .not8a
  cmp al, 0xBF
  ja .not8a
  sub al, 0x30
  ret
.not8a:
  cmp al, 0xC0
  jb .not8b
  cmp al, 0xC7
  ja .not8b
  sub al, 0xC0
  add eax, 280
  ret
.not8b:
  mov cl, 1
  call get_n_bits
  shl eax, 8
  or ebx, eax
  mov eax, ebx
  mov cl, 9
  call bitrev
  sub eax, 0x190
  add eax, 144
  ret

bitrev:
  push ebx
  mov ebx, eax
  xor eax, eax
.loop:
  shr ebx, 1
  rcl eax, 1
  dec cl
  jnz .loop
  pop ebx
  ret

; ------------------------------------------------------------------------------
; LENGTH / DISTANCE DECODERS
; ------------------------------------------------------------------------------
decode_length:
  cmp al, 8
  jb .direct
  cmp al, 28
  je .max
  mov cl, al
  sub cl, 8
  mov dl, cl
  shr dl, 2
  and cl, 3
  mov al, 11
  push dx
  shl dl, 2
  add al, dl
  add al, cl
  pop dx
  mov cl, dl
  inc cl
  push ax
  call get_n_bits
  pop cx
  add al, cl
  movzx eax, al
  ret
.direct:
  add al, 3
  movzx eax, al
  ret
.max:
  mov eax, 258
  ret

decode_distance:
  cmp al, 4
  jb .direct
  mov cl, al
  sub cl, 2
  shr cl, 1
  mov dl, al
  and dl, 1
  push ax
  mov al, 1
  mov ch, cl
  inc ch
  shl al, ch
  inc al
  mov ch, cl
  shl dl, ch
  add al, dl
  mov dl, al
  mov al, cl
  push dx
  call get_n_bits
  pop dx
  add al, dl
  movzx eax, al
  ret
.direct:
  inc eax
  ret

; ------------------------------------------------------------------------------
; LZ77 MATCH COPY (byte-by-byte via memfd window)
; ------------------------------------------------------------------------------
copy_match:
  push ecx
  push eax
.loop:
  push 19
  pop eax
  mov ebx, [memfd]
  mov ecx, [esp]
  neg ecx
  mov edx, 1
  int 0x80
  push 3
  pop eax
  mov ecx, buf
  mov edx, 1
  int 0x80
  push 19
  pop eax
  xor ecx, ecx
  mov edx, 2
  int 0x80
  push 4
  pop eax
  mov ecx, buf
  mov edx, 1
  int 0x80
  dec dword [esp+4]
  jnz .loop
  pop eax
  pop ecx
  ret

; ==============================================================================
; DATA
; ==============================================================================
pkgname: db "upkg", 0

; ==============================================================================
; FILE PADDING: force exactly 1024 bytes on disk
; ==============================================================================
file_end:
times (1024 - ($ - $$)) db 0

; ==============================================================================
; BSS (RAM only — absolute addresses, not in the file)
; ==============================================================================
bss_start equ $$ + 1024

bit_buf:    equ bss_start + 0
nbits:      equ bit_buf + 4
in_ptr:     equ nbits + 1
in_end:     equ in_ptr + 4
memfd:      equ in_end + 4
flags:      equ memfd + 4
bfinal:     equ flags + 1
saved_argv: equ bfinal + 1
saved_envp: equ saved_argv + 4
buf:        equ saved_envp + 4
bss_end:    equ buf + 1024
