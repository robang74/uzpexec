; ==============================================================================
; uskexz.asm - uskex + zcat popen
; 1. Legge da argv[0] o stdin
; 2. Scarta 512 byte
; 3. Crea pipe, fork, esegue zcat
; 4. Scrive dati gzip su zcat, legge output, scrive su memfd
; 5. execveat il memfd
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
; dw 0, 0, 0

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
; mov eax, 5
  push 5
  pop eax
  int 0x80
  test eax, eax
  js exit_error
  mov edi, eax                ; input fd
  jmp .memfd

.stdin:
  xor edi, edi

  ; Create memfd
.memfd:
  mov eax, 356
  mov ebx, filename
  push 1
  pop ecx
  int 0x80
  test eax, eax
  js exit_error
  push eax                    ; [esp+4] = memfd (save later)

  ; Create pipe for zcat input
  ; mov eax, 42                 ; SYS_pipe
  push 42
  pop eax
  mov ebx, pipefd
  int 0x80
  js exit_error

  ; Create pipe for zcat output
; mov eax, 42
  push 42
  pop eax
  mov ebx, pipeout
  int 0x80
  js exit_error

  ; fork
; mov eax, 2
  push 2
  pop eax
  int 0x80
  test eax, eax
  jz child

  ; === PARENT ===
  ; close pipefd[0] (read end of input pipe)
; mov eax, 6
  push 6
  pop eax
  mov ebx, [pipefd]
  int 0x80
  ; close pipeout[1] (write end of output pipe)
; mov eax, 6
  push 6
  pop eax
  mov ebx, [pipeout+4]
  int 0x80

  ; Skip 512 bytes from input
  mov ecx, buf
  mov edx, 512
.skip_loop:
; mov eax, 3
  push 3
  pop eax
  mov ebx, edi
  int 0x80
  test eax, eax
  js exit_error
  jz read_zcat                ; EOF during skip -> jump to read_zcat (label globale)
  sub edx, eax
  jnz .skip_loop

  ; Read from input, write to zcat stdin (pipefd[1])
  ; AND read from zcat stdout (pipeout[0]), write to memfd
.copy_loop:
  ; Read from input
; mov eax, 3
  push 3
  pop eax
  mov ebx, edi
  mov ecx, buf
  mov edx, 512
  int 0x80
  test eax, eax
  js exit_error
  jz close_zcat_in            ; EOF on input

  ; Write to zcat stdin
  mov edx, eax
; mov eax, 4
  push 4
  pop eax
  mov ebx, [pipefd+4]
  mov ecx, buf
  int 0x80

  ; Read from zcat stdout
; mov eax, 3
  push 3
  pop eax
  mov ebx, [pipeout]
  mov ecx, buf
  mov edx, 512
  int 0x80
  test eax, eax
  jle .copy_loop            ; 0 or error, continue

  ; Write to memfd
  mov edx, eax
; mov eax, 4
  push 4
  pop eax
  mov ebx, [esp+4]          ; memfd
  mov ecx, buf
  int 0x80
  jmp .copy_loop

close_zcat_in:
  ; Close zcat input to signal EOF
; mov eax, 6
  push 6
  pop eax
  mov ebx, [pipefd+4]
  int 0x80

  ; Read remaining output from zcat
read_zcat:
.drain_loop:
; mov eax, 3
  push 3
  pop eax
  mov ebx, [pipeout]
  mov ecx, buf
  mov edx, 512
  int 0x80
  test eax, eax
  jle execute
  mov edx, eax
; mov eax, 4
  push 4
  pop eax
  mov ebx, [esp+4]
  mov ecx, buf
  int 0x80
  jmp .drain_loop

  ; Execute
execute:
  mov [esi], ebx              ; argv[0] = filename (EBX still points from last write)
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
; mov eax, 6
  push 6
  pop eax
  mov ebx, [pipefd+4]
  int 0x80
  ; close pipeout[0] (read end of output)
; mov eax, 6
  push 6
  pop eax
  mov ebx, [pipeout]
  int 0x80

  ; dup2(pipefd[0], 0) - stdin
; mov eax, 63
  push 63
  pop eax
  mov ebx, [pipefd]
  xor ecx, ecx
  int 0x80

  ; dup2(pipeout[1], 1) - stdout
; mov eax, 63
  push 63
  pop eax
  mov ebx, [pipeout+4]
  mov ecx, 1
  int 0x80

  ; execve zcat
; mov eax, 11
  push 11
  pop eax
  mov ebx, zcat_path
  push 0
  push zcat_arg
  push zcat_path
  mov ecx, esp
  xor edx, edx
  int 0x80
  ; if execve fails, exit
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
filename:   db "upkg", 0
zcat_path:  db "/bin/zcat", 0
zcat_arg:   db "-", 0

; ==============================================================================
; PADDING: 512 bytes
; ==============================================================================
file_end:
times (512 - ($ - $$)) db 0

; ==============================================================================
; BSS
; ==============================================================================
bss_start equ $$ + 512

pipefd:     equ bss_start + 0    ; 2 dwords
pipeout:    equ pipefd + 8       ; 2 dwords
buf:        equ pipeout + 8
bss_end:    equ buf + 512
