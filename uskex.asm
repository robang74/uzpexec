; ==============================================================================
; upkg_step2.asm - Step 2: Skip 1536 bytes, copy to memfd, execveat
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
; CODE
; ==============================================================================
code_start:
  pop eax                     ; argc
  mov esi, esp                ; argv
  lea ebp, [esi+eax*4+4]      ; envp

  ; Save argv/envp for execveat
  mov [saved_argv], esi
  mov [saved_envp], ebp

  ; Open argv[0] or use stdin
  mov ebx, [esi]
  test ebx, ebx
  jz .stdin
  cmp byte [ebx], 0
  jz .stdin
  xor ecx, ecx                ; O_RDONLY
  mov eax, 5                  ; SYS_open
  int 0x80
  test eax, eax
  js exit_error
  mov edi, eax                ; EDI = input fd
  jmp .memfd

.stdin:
  xor edi, edi                ; EDI = stdin

  ; Create memfd
.memfd:
  mov eax, 356                ; SYS_memfd_create
  mov ebx, pkgname
  push 1                      ; MFD_CLOEXEC
  pop ecx
  int 0x80
  test eax, eax
  js exit_error
  mov [memfd], eax            ; Save memfd

  ; Discard first 1536 bytes
.discard:
  mov ecx, buf
  mov edx, 1536
.discard_loop:
  mov eax, 3                  ; SYS_read
  mov ebx, edi
  int 0x80
  test eax, eax
  js exit_error
  jz .execute                 ; EOF during discard = nothing to execute
  sub edx, eax
  jnz .discard_loop

  ; Copy loop: read from input, write to memfd
.copy_loop:
  mov eax, 3                  ; SYS_read
  mov ebx, edi
  mov ecx, buf
  mov edx, 1536
  int 0x80
  test eax, eax
  js exit_error
  jz .execute                 ; EOF
  mov edx, eax                ; bytes read
  mov eax, 4                  ; SYS_write
  mov ebx, [memfd]
  mov ecx, buf
  int 0x80
  js exit_error
  jmp .copy_loop

  ; Execute via execveat
.execute:
  mov eax, [saved_argv]
  mov [eax], ebx              ; argv[0] = pkgname (EBX still points to pkgname)
  mov eax, 358                ; SYS_execveat
  mov ebx, [memfd]
  push 0
  mov ecx, esp                ; empty path
  mov edx, [saved_argv]
  mov esi, [saved_envp]
  mov edi, 0x1000             ; AT_EMPTY_PATH
  int 0x80

exit_error:
  push 1
  pop eax
  xor ebx, ebx
  inc ebx
  int 0x80

; ==============================================================================
; DATA
; ==============================================================================
pkgname: db "uskex", 0

; ==============================================================================
; PADDING: force exactly 1536 bytes on disk
; ==============================================================================
file_end:
times (1536 - ($ - $$)) db 0

; ==============================================================================
; BSS (RAM only)
; ==============================================================================
bss_start equ $$ + 1536

memfd:      equ bss_start + 0
saved_argv: equ memfd + 4
saved_envp: equ saved_argv + 4
buf:        equ saved_envp + 4
bss_end:    equ buf + 1536
