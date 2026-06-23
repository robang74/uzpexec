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
  ; Salva l'inizializzazione dello stack (argc, argv, envp)
  pop eax                     ; argc
  mov esi, esp                ; ESI = argv
  lea ebp, [esi+eax*4+4]      ; EBP = envp

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
  jmp .create_memfd

.stdin:
  xor edi, edi                ; EDI = 0 (stdin)

  ; Create memfd, save on stack
.create_memfd:
  mov eax, 356                ; SYS_memfd_create
  mov ebx, filename
  push 1                      ; MFD_CLOEXEC
  pop ecx
  int 0x80
  test eax, eax
  js exit_error
  ; Ora abbiamo: EDI = input fd, mentre salviamo il memfd nello stack o in un altro registro.
  ; Per comodità e fedeltà, teniamo il memfd in EDX temporaneamente o lo invertiamo.
  ; Usiamo: EDI = input fd, edx = memfd -> spostiamo memfd in un registro stabile.
  ; Scegliamo: EDI = input fd, EBX = memfd (ma ebx serve per le syscall, quindi usiamo una variabile o lo stack).
  ; Per massimizzare i registri liberi: manteniamo EDI = input fd, ed usiamo una locazione in RAM o lo stack.
  ; Optiamo per spingere il memfd nello stack temporaneamente per liberare i registri durante il loop.
  push eax                    ; [esp] = memfd

  ; Discard first 512 bytes
.discard:
  mov ecx, buf
  mov edx, 512
.discard_loop:
  mov eax, 3                  ; SYS_read
  mov ebx, edi                ; input fd
  int 0x80
  test eax, eax
  js exit_error
  jz .execute                 ; premature EOF
  sub edx, eax
  jnz .discard_loop

  ; 4. Copy loop: read from input, write to memfd
.copy_loop:
  mov eax, 3                  ; SYS_read
  mov ebx, edi                ; input fd
  mov ecx, buf                ; Ripristina il puntatore del buffer
  mov edx, 512                ; Legge a blocchi di 512 byte
  int 0x80
  test eax, eax
  js exit_error
  jz .execute                 ; EOF
  mov edx, eax                ; bytes read
  mov eax, 4                  ; SYS_write
  mov ebx, [esp]              ; memfd from stack
  mov ecx, buf
  int 0x80
  js exit_error
  jmp .copy_loop

  ; Execute via execveat
.execute:
  mov [esi], ebx              ; argv[0] = pkgname (EBX still points to pkgname)
  mov eax, 358                ; SYS_execveat
  pop ebx                     ; EBX = memfd
  push 0
  mov ecx, esp                ; ECX = ""
  mov edx, esi                ; EDX = argv
  mov esi, ebp                ; ESI = envp
  mov edi, 0x1000             ; EDI = AT_EMPTY_PATH
  int 0x80

exit_error:
  push 1
  pop eax
  xor ebx, ebx
  inc ebx
  int 0x80

; ==============================================================================
; COMPACT DATA SECTION (Appended to code)
; ==============================================================================
filename: db "uskex", 0       ; This is the /proc/self/cmdline executable name
file_end:                     ; Physical end of the binary file!
times (512 - ($ - $$)) db 0   ; Padding the file on disk up to 512 bytes of size

; ==============================================================================
; UNINITIALIZED BSS SECTION (Exists ONLY in RAM)
; ==============================================================================
absolute_address equ $
buf equ file_end + 4          ; It starts immediately after the EOF
bss_end equ buf + 512         ; Reserve 512 bytes for the buffer

