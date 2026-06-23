; ==============================================================================
; uskexz_fixed.asm - Fix dell'architettura a 2 pipe per zcat
; 1. Legge se stesso (da argv[0] o stdin)
; 2. Scarta i primi 1024 byte (skip dell'header/loader)
; 3. Invia il resto a zcat tramite pipe
; 4. Legge l'output spacchettato da zcat e lo carica in un memfd anonimo
; 5. Esegue il codice dal memfd
; ==============================================================================

BITS 32
org 0x08048000

; ==============================================================================
; ELF32 HEADER
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

  ; Apertura input (se stesso o stdin)
  mov ebx, [esi]
  test ebx, ebx
  jz .stdin
  cmp byte [ebx], 0
  jz .stdin
  xor ecx, ecx                ; O_RDONLY
  push 5                      ; SYS_open
  pop eax
  int 0x80
  test eax, eax
  js exit_error
  mov edi, eax                ; EDI = input fd
  jmp .pipes

.stdin:
  xor edi, edi                ; EDI = stdin

  ; Creazione delle pipe prima della fork
.pipes:
  push 42                     ; SYS_pipe
  pop eax
  mov ebx, pipefd             ; Pipe per input di zcat
  int 0x80
  js exit_error
  ; pipefd = [read_fd, write_fd] - save them
  mov eax, [pipefd]
  mov [pipefd_rd], eax
  mov eax, [pipefd+4]
  mov [pipefd_wr], eax

  push 42                     ; SYS_pipe
  pop eax
  mov ebx, pipeout            ; Pipe per output di zcat
  int 0x80
  js exit_error
  ; pipeout = [read_fd, write_fd] - save them
  mov eax, [pipeout]
  mov [pipeout_rd], eax
  mov eax, [pipeout+4]
  mov [pipeout_wr], eax

  ; Creazione del descrittore di memoria anonimo (memfd)
  mov eax, 356                ; SYS_memfd_create
  mov ebx, filename
  push 1                      ; MFD_CLOEXEC
  pop ecx
  int 0x80
  test eax, eax
  js exit_error
  push eax                    ; [esp] = memfd

  ; Fork
  push 2                      ; SYS_fork
  pop eax
  int 0x80
  test eax, eax
  jz child                    ; Se EAX == 0, vai al processo figlio

  ; ============================================================================
  ; PARENT PROCESS
  ; ============================================================================
  ; CHIUSURA IMMEDIATA DEI DESCRITTORI LATO FIGLIO NEL PADRE
  push 6                      ; SYS_close
  pop eax
  mov ebx, [pipefd_rd]        ; Il padre non legge dalla pipe di input di zcat
  int 0x80
  ; close pipeout[1] (write end of zcat output)
  push 6                      ; SYS_close
  pop eax
  mov ebx, [pipeout_wr]       ; Il padre non scrive nella pipe di output di zcat
  int 0x80

  ; Salto dei primi 1024 byte dall'input di partenza (Richiesta: Blocco da 1024)
  mov ecx, buf
  mov edx, 1024
.skip_loop:
  push 3                      ; SYS_read
  pop eax
  mov ebx, edi                ; input fd
  int 0x80
  test eax, eax
  js exit_error
  jz .close_input             ; EOF during skip
  sub edx, eax
  jnz .skip_loop

  ; Write ALL remaining input to zcat stdin (pipefd[1])
.write_loop:
  push 3                      ; SYS_read
  pop eax
  mov ebx, edi                ; input fd
  mov ecx, buf
  mov edx, 1024
  int 0x80
  test eax, eax
  js exit_error
  jz .close_input             ; Finita la lettura (EOF)
  
  mov edx, eax                ; byte letti
  push 4                      ; SYS_write
  pop eax
  mov ebx, [pipefd_wr]        ; Scrive su zcat stdin
  mov ecx, buf
  int 0x80
  jmp .write_loop

.close_input:
  ; Chiude il lato di scrittura della pipe di input. 
  ; Questo invia finalmente l'EOF a zcat!
  push 6                      ; SYS_close
  pop eax
  mov ebx, [pipefd_wr]
  int 0x80

  ; Se l'input era un file aperto (diverso da stdin), chiudilo
  test edi, edi
  jz .read_loop
  push 6                      ; SYS_close
  pop eax
  mov ebx, edi
  int 0x80

  ; Lettura dell'output decompresso da zcat (pipeout_rd) e scrittura nel memfd
.read_loop:
  push 3                      ; SYS_read
  pop eax
  mov ebx, [pipeout_rd]
  mov ecx, buf
  mov edx, 1024
  int 0x80
  test eax, eax
  js exit_error
  jz execute                  ; zcat ha finito ed è uscito regolarmente (EOF)

  mov edx, eax
  push 4                      ; SYS_write
  pop eax
  mov ebx, [esp+4]            ; Recupera il memfd salvato nello stack
  mov ecx, buf
  int 0x80
  jmp .read_loop

execute:
  ; Configura argv[0] con il nome fittizio
  mov [esi], ebx              
  
  mov eax, 358                ; SYS_execveat
  pop ebx                     ; Preleva il memfd dallo stack (diventa EBX)
  push 0                      ; Path vuoto "" per AT_EMPTY_PATH
  mov ecx, esp
  mov edx, esi                ; argv
  mov esi, ebp                ; envp
  mov edi, 0x1000             ; AT_EMPTY_PATH
  int 0x80
  jmp exit_error

  ; ============================================================================
  ; CHILD PROCESS (Esegue zcat)
  ; ============================================================================
child:
  ; IMPORTANTE: Chiude i descrittori del lato padre per evitare il blocco (hang)
  push 6                      ; SYS_close
  pop eax
  mov ebx, [pipefd_wr]        ; Chiude il lato di scrittura della pipe di input!
  int 0x80

  push 6                      ; SYS_close
  pop eax
  mov ebx, [pipeout_rd]       ; Chiude il lato di lettura della pipe di output!
  int 0x80

  ; Dup2: Collega pipefd_rd allo STDIN (fd 0)
  push 63                     ; SYS_dup2
  pop eax
  mov ebx, [pipefd_rd]
  xor ecx, ecx                ; 0 = stdin
  int 0x80

  ; Dup2: Collega pipeout_wr allo STDOUT (fd 1)
  push 63                     ; SYS_dup2
  pop eax
  mov ebx, [pipeout_wr]
  mov ecx, 1                  ; 1 = stdout
  int 0x80

  ; Esecuzione di: /bin/zcat --synchronous -f -
  push 11                     ; SYS_execve
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
  push 1                      ; SYS_exit
  pop eax
  xor ebx, ebx
  inc ebx                     ; Exit code 1
  int 0x80

; ==============================================================================
; DATA SECTION
; ==============================================================================
filename:   db "uzkex", 0
zcat_path:  db "/bin/zcat", 0
sync_arg:   db "--synchronous", 0
f_arg:      db "-f", 0
dash_arg:   db "-", 0

; ==============================================================================
; PADDING: Allineato esattamente a 1024 byte (come da richiesta skip)
; ==============================================================================
file_end:
times (1024 - ($ - $$)) db 0

; ==============================================================================
; BSS SECTION (Solo in RAM)
; ==============================================================================
bss_start equ $$ + 1024

pipefd:     equ bss_start + 0
pipeout:    equ pipefd + 8
pipefd_rd:  equ pipeout + 8
pipefd_wr:  equ pipefd_rd + 4
pipeout_rd: equ pipefd_wr + 4
pipeout_wr: equ pipeout_rd + 4
buf:        equ pipeout_wr + 4
bss_end:    equ buf + 1024

