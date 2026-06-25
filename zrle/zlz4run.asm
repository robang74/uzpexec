; ==============================================================================
;
; (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT+1 license
;
;     MIT+1: due to the extreme nature of this software, an extra clause is
;            added to the standard MIT license, which forbids everyone to
;            remove or change the authorship string also from the binary.
;
; ==============================================================================
;
; Single-Process Universal LZ4 Architecture (FIXED):
; - 1. Reads itself (from argv[0] or stdin)
; - 2. Discards the first 512 bytes if opening itself via file path
; - 3. Creates an anonymous memfd (without MFD_CLOEXEC for script support)
; - 4. Decodes byte-aligned LZ4 frames directly into a massive BSS memory buffer
; - 5. Emits the decompressed block to the memfd and executes via execveat
;
; ==============================================================================

BITS 32
org 0x08048000

; ==============================================================================
; ELF32 HEADER
; ==============================================================================
elf_header:
  db 0x7F, 'ELF', 1, 1, 1, 0  ; e_ident
  times 8 db 0                ; Padding
  dw 2                        ; e_type (Executable)
  dw 3                        ; e_machine (Intel 80386)
  dd 1                        ; e_version
  dd main_start               ; e_entry
  dd phdr - elf_header        ; e_phoff
  dd 0                        ; e_shoff
  dd 0                        ; e_flags
  dw 52                       ; e_ehsize
  dw 32                       ; e_phentsize
  dw 1                        ; e_phnum
; dw 0, 0, 0                  ; Section info

phdr:
  dd 1                        ; p_type (PT_LOAD)
  dd 0                        ; p_offset
  dd 0x08048000               ; p_vaddr
  dd 0x08048000               ; p_paddr
  dd file_end - elf_header    ; p_filesz
  dd bss_end - elf_header     ; p_memsz
  dd 7                        ; p_flags (R+W+X)
  dd 0x1000                   ; p_align

; ==============================================================================
; upexec CODE
; ==============================================================================
main_start:
  pop eax                     ; argc
  mov esi, esp                ; ESI = argv
  mov [argv_ptr], esi         ; Persist original argv base pointer
  lea ebp, [esi+eax*4+4]      ; EBP = envp

  ; 1. Checking argv[0] to open input
  mov ebx, [esi]
  test ebx, ebx
  jz .stdin
  cmp byte [ebx], 0
  jz .stdin

  mov edx, ebx
.find_end:
  inc edx
  cmp byte [edx], 0
  jnz .find_end

.backtrack:
  cmp edx, ebx
  je .do_strcmp
  dec edx
  cmp byte [edx], '/'
  jne .backtrack
  inc edx

.do_strcmp:
  mov ecx, filename

.strcmp_loop:
  mov al, [edx]
  mov ah, [ecx]
  cmp al, ah
  jne .not_uzpexec
  test al, al
  jz .stdin
  inc edx
  inc ecx
  jmp .strcmp_loop

.not_uzpexec:
  xor ecx, ecx                  ; O_RDONLY
  push 5                        ; SYS_open
  pop eax
  int 0x80
  mov edi, eax                  ; EDI = input fd

  ; Skip 512-byte block
  mov ecx, buf
  mov edx, 512
.skip_loop:
  push 3                        ; SYS_read
  pop eax
  mov ebx, edi
  int 0x80
  test eax, eax
  jle exit_error
  sub edx, eax
  jnz .skip_loop
  jmp .memfd

.stdin:
  xor edi, edi                  ; EDI = stdin

.memfd:
  mov [input_fd], edi           ; PRESERVE DESCRIPTOR: Save before EDI gets repurposed
  mov ebx, filename             ; Name string pointer
  mov eax, 356                  ; SYS_memfd_create
  xor ecx, ecx                  ; flags = 0 (Keep fd unmapped for scripts)
  xor edx, edx                  
  int 0x80
  mov [memfd], eax

; ==============================================================================
; HIGH-PERFORMANCE LZ4 DECOMPRESSOR ENGINE
; ==============================================================================
  xor ecx, ecx                  ; Force immediate initial block read
  mov edi, decomp_buf           ; EDI = Decompression output pointer

.block_loop:
  call fetch_byte
  jc .flush_memfd               ; EOF at token boundaries indicates clean termination

  mov dl, al                    ; Save copy of token inside DL
  
  ; --- Parse Literal Length ---
  xor ebx, ebx
  mov bl, al
  shr bl, 4                     ; Extract upper 4 bits
  cmp bl, 15
  jne .got_lit_len

.lit_len_loop:
  push ebx
  call fetch_byte
  movzx eax, al
  pop ebx
  add ebx, eax
  cmp eax, 255                  ; Multi-byte extension check
  je .lit_len_loop

.got_lit_len:
  test ebx, ebx
  jz .get_offset

.copy_lit_loop:
  push ebx
  call fetch_byte
  stosb                         ; Copy literal directly into BSS workspace
  pop ebx
  dec ebx
  jnz .copy_lit_loop

.get_offset:
  call fetch_byte               ; Fetch offset low byte
  jc .flush_memfd               ; Clean check for trailing literal-only blocks
  mov bl, al
  call fetch_byte               ; Fetch offset high byte
  mov bh, al                    ; BX = 16-bit match back-reference offset

  ; --- Parse Match Length ---
  xor eax, eax
  mov al, dl
  and al, 0x0F                  ; Extract lower 4 bits from saved token
  cmp al, 15
  jne .got_match_len

.match_len_loop:
  push eax
  call fetch_byte
  movzx edx, al
  pop eax
  add eax, edx
  cmp edx, 255                  ; Multi-byte extension check
  je .match_len_loop

.got_match_len:
  add eax, 4                    ; LZ4 minimum match constraint behavior

  ; --- Copy Match from Dictionary History ---
  push esi                      ; Safely preserve input buffer cursor position
  mov esi, edi
  sub esi, ebx                  ; ESI = Dictionary match source window location
  mov edx, eax                  ; EDX = length loop counter
.copy_match_loop:
  movsb                         ; Safe overlapping byte transfer
  dec edx
  jnz .copy_match_loop
  pop esi                       ; Restore input stream position
  jmp .block_loop

; ==============================================================================
; FLUSH & EXECUTING STAGE
; ==============================================================================
.flush_memfd:
  ; 1. Calculate length and write extracted buffer into memfd
  mov edx, edi
  mov ecx, decomp_buf
  sub edx, ecx                  ; EDX = Unpacked footprint size
  mov ebx, [memfd]              ; Target destination descriptor
  mov eax, 4                    ; SYS_write
  int 0x80

  ; 2. Close input handle if it wasn't stdin
  mov ebx, [input_fd]
  test ebx, ebx
  jz .run
  push 6                        ; SYS_close
  pop eax
  int 0x80

.run:
  ; 3. Rewind internal file offset back to zero for execution
  push 19                       ; SYS_lseek
  pop eax
  mov ebx, [memfd]
  xor ecx, ecx
  xor edx, edx                  ; SEEK_SET
  int 0x80

  ; 4. Re-map image
  mov eax, 358                  ; SYS_execveat
  mov ebx, [memfd]              ; EBX = target memfd
  push 0                        ; push empty string
  mov ecx, esp                  ; ECX = path target points to ""
  mov edx, [argv_ptr]           ; EDX = original unmodified parameters
  mov esi, ebp                  ; ESI = environment array
  mov edi, 0x1000               ; EDI = AT_EMPTY_PATH
  int 0x80
  jmp exit_error

; ==============================================================================
; UTILITY SUBROUTINES
; ==============================================================================
fetch_byte:
  test ecx, ecx
  jnz .from_buf

  push edx
  push ebx
  mov eax, 3                    ; SYS_read
  mov ebx, [input_fd]           ; Read directly using fixed BSS descriptor pointer
  mov ecx, buf
  mov edx, 512
  int 0x80
  pop ebx
  pop edx

  test eax, eax
  jle .eof

  mov ecx, eax                  
  mov esi, buf                  

.from_buf:
  lodsb                         
  dec ecx
  clc                           
  ret

.eof:
  stc                           
  ret

exit_error:
  push 1                        ; SYS_exit
  pop eax
  xor ebx, ebx
  inc ebx                       ; exit code 1
  int 0x80

; ==============================================================================
; DATA STRUCTURES
; ==============================================================================
copy_vers:  db "(c) github/robang74 v0.85", 0
filename:   db "z4l", 0
eof_strng:  db "eOf", 0

; Aligned to exactly 512 bytes on disk
file_end:
times (511 - ($ - $$)) db 0
end_code: db 0

; ==============================================================================
; RUNTIME MEMORY ALLOCATION (BSS)
; ==============================================================================
bss_start equ $$ + 512

memfd:       equ bss_start + 0
argv_ptr:    equ bss_start + 4     
input_fd:    equ bss_start + 8  ; 4-byte slot to safely anchor file descriptor
buf:         equ bss_start + 12
decomp_buf:  equ buf + 512      ; Buffer memory where the binary is constructed
bss_end:     equ decomp_buf + 4*1024*1024 ; Map 4MB anonymous memory space for decompression
