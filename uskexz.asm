; ==============================================================================
; uskexz.asm - uskex + zcat popen (1024 byte, zcat --synchronous -f -)
; Architettura: 2 pipe (input+output), fork, write-all -> close -> read-all
; ==============================================================================

BITS 32
org 0x08048000

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

phdr:
  dd 1
  dd 0
  dd 0x08048000
  dd 0x08048000
  dd file_end - elf_header
  dd bss_end - elf_header
  dd 7
  dd 0x1000

code_start:
  pop eax
  mov esi, esp                ; argv
  lea ebp, [esi+eax*4+4]      ; envp

  ; Open input
  mov ebx, [esi]
  test ebx, ebx
  jz .stdin
  cmp byte [ebx], 0
  jz .stdin
  xor ecx, ecx
  push 5
  pop eax
  int 0x80
  test eax, eax
  js exit_error
  mov edi, eax                ; EDI = input fd
  jmp .pipes

.stdin:
  xor edi, edi

  ; Create both pipes before fork
.pipes:
  push 42
  pop eax
  mov ebx, pipefd             ; pipe for zcat input
  int 0x80
  js exit_error

  push 42
  pop eax
  mov ebx, pipeout            ; pipe for zcat output
  int 0x80
  js exit_error

  ; Create memfd
  mov eax, 356
  mov ebx, filename
  push 1
  pop ecx
  int 0x80
  test eax, eax
  js exit_error
  push eax                    ; [esp] = memfd

  ; fork
  push 2
  pop eax
  int 0x80
  test eax, eax
  jz child

  ; === PARENT ===
  ; close pipefd[0] (read end of zcat input)
  push 6
  pop eax
  mov ebx, [pipefd]
  int 0x80
  ; close pipeout[1] (write end of zcat output)
  push 6
  pop eax
  mov ebx, [pipeout+4]
  int 0x80

  ; Skip 1024 bytes from input
  mov ecx, buf
  mov edx, 1024
.skip_loop:
  push 3
  pop eax
  mov ebx, edi
  int 0x80
  test eax, eax
  js exit_error
  jz .close_input             ; EOF during skip
  sub edx, eax
  jnz .skip_loop

  ; Write ALL remaining input to zcat stdin (pipefd[1])
.write_loop:
  push 3
  pop eax
  mov ebx, edi
  mov ecx, buf
  mov edx, 1024
  int 0x80
  test eax, eax
  js exit_error
  jz .close_input             ; EOF
  mov edx, eax
  push 4
  pop eax
  mov ebx, [pipefd+4]
  mov ecx, buf
  int 0x80
  jmp .write_loop

.close_input:
  ; Close zcat input pipe to signal EOF
  push 6
  pop eax
  mov ebx, [pipefd+4]
  int 0x80

  ; Read ALL output from zcat stdout (pipeout[0]), write to memfd
.read_loop:
  push 3
  pop eax
  mov ebx, [pipeout]
  mov ecx, buf
  mov edx, 1024
  int 0x80
  test eax, eax
  jle execute
  mov edx, eax
  push 4
  pop eax
  mov ebx, [esp+4]            ; memfd
  mov ecx, buf
  int 0x80
  jmp .read_loop

execute:
  mov [esi], ebx              ; argv[0] = filename
  mov eax, 358
  pop ebx                     ; memfd
  push 0
  mov ecx, esp
  mov edx, esi
  mov esi, ebp
  mov edi, 0x1000
  int 0x80

  ; === CHILD ===
child:
  ; close pipefd[1] (write end of input)
  push 6
  pop eax
  mov ebx, [pipefd+4]
  int 0x80
  ; close pipeout[0] (read end of output)
  push 6
  pop eax
  mov ebx, [pipeout]
  int 0x80

  ; dup2(pipefd[0], 0) - stdin
  push 63
  pop eax
  mov ebx, [pipefd]
  xor ecx, ecx
  int 0x80

  ; dup2(pipeout[1], 1) - stdout
  push 63
  pop eax
  mov ebx, [pipeout+4]
  mov ecx, 1
  int 0x80

  ; execve zcat --synchronous -
  push 11
  pop eax
  mov ebx, zcat_path
  push 0
  push dash_arg
  push f_arg
  push sync_arg
  push zcat_path
  mov ecx, esp
  xor edx, edx
  int 0x80
  jmp exit_error

exit_error:
  push 1
  pop eax
  xor ebx, ebx
  inc ebx
  int 0x80

; ==============================================================================
; DATA
; ==============================================================================
filename:   db "uzkex", 0
zcat_path:  db "/bin/zcat", 0
sync_arg:   db "--synchronous", 0
f_arg:      db "-f", 0
dash_arg:   db "-", 0

; ==============================================================================
; PADDING: 1024 bytes
; ==============================================================================
file_end:
times (1024 - ($ - $$)) db 0

; ==============================================================================
; BSS
; ==============================================================================
bss_start equ $$ + 1024

pipefd:     equ bss_start + 0    ; 2 dwords
pipeout:    equ pipefd + 8       ; 2 dwords
buf:        equ pipeout + 8
bss_end:    equ buf + 1024
