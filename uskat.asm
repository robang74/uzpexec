; ==============================================================================
; upkg_step1.asm - Step 1: Cat with 512-byte skip
; Legge da argv[0] o stdin, scarta i primi 512 byte, scrive il resto su stdout
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

  ; Open argv[0] or use stdin
  mov ebx, [esi]              ; argv[0]
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
  jmp .discard

.stdin:
  xor edi, edi                ; EDI = stdin

  ; Discard first 512 bytes
.discard:
  mov ecx, buf
  mov edx, 512
.discard_loop:
  mov eax, 3                  ; SYS_read
  mov ebx, edi
  int 0x80
  test eax, eax
  js exit_error
  jz exit_ok                  ; EOF during discard = nothing to copy
  sub edx, eax
  jnz .discard_loop

  ; Copy loop: read from input, write to stdout
.copy_loop:
  mov eax, 3                  ; SYS_read
  mov ebx, edi
  mov ecx, buf
  mov edx, 512
  int 0x80
  test eax, eax
  js exit_error
  jz exit_ok                  ; EOF
  mov edx, eax                ; bytes read
  mov eax, 4                  ; SYS_write
  mov ebx, 1                  ; stdout
  mov ecx, buf
  int 0x80
  js exit_error
  jmp .copy_loop

exit_ok:
  xor ebx, ebx
exit_error:
  push 1
  pop eax
  int 0x80

; ==============================================================================
; COMPACT DATA SECTION (Appended to code)
; ==============================================================================
filename: db "uskat", 0       ; This is the /proc/self/cmdline executable name
file_end:                     ; Physical end of the binary file!
times (512 - ($ - $$)) db 0   ; Padding the file on disk up to 512 bytes of size

; ==============================================================================
; UNINITIALIZED BSS SECTION (Exists ONLY in RAM)
; ==============================================================================
absolute_address equ $
buf equ file_end + 4          ; It starts immediately after the EOF
bss_end equ buf + 512         ; Reserve 512 bytes for the buffer

