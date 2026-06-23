; ==============================================================================
; uskexz_fixed.asm - Fix dell'architettura a 2 pipe per zcat
; 1. Legge se stesso (da argv[0] o stdin)
; 2. Scarta i primi 512 byte (skip dell'header/loader)
; 3. Invia il resto a zcat tramite pipe
; 4. Legge l'output spacchettato da zcat e lo carica in un memfd anonimo
; 5. Esegue il codice dal memfd
; Ottimizzazione a Singola Pipe con Scrittura Diretta
; Architettura: 1 pipe (input), fork, child scrive direttamente su memfd via dup2
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

  ; 1. Apertura input (se stesso o stdin)
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
  jmp .memfd

.stdin:
  xor edi, edi                ; EDI = stdin (0)

  ; 2. Creazione memfd
.memfd:
  mov eax, 356                ; SYS_memfd_create
  mov ebx, filename
  push 1                      ; MFD_CLOEXEC
  pop ecx
  int 0x80
  test eax, eax
  js exit_error
  mov [memfd_saved], eax      ; Salviamo il memfd nella BSS

  ; 3. Creazione dell'UNICA pipe (per l'input di zcat)
  push 42                     ; SYS_pipe
  pop eax
  mov ebx, pipefd
  int 0x80
  js exit_error

  ; 4. Fork
  push 2                      ; SYS_fork
  pop eax
  int 0x80
  test eax, eax
  jz child                    ; Se EAX == 0, vai al processo figlio

  ; ============================================================================
  ; PARENT PROCESS (Alimenta zcat)
  ; ============================================================================
  ; Chiude il lato lettura della pipe (usato solo dal figlio)
  push 6                      ; SYS_close
  pop eax
  mov ebx, [pipefd]           ; Il padre non legge dalla pipe di input di zcat
  int 0x80

  ; Skip del blocco iniziale da 512 byte
  mov ecx, buf
  mov edx, 512
.skip_loop:
  push 3                      ; SYS_read
  pop eax
  mov ebx, edi                ; input fd
  int 0x80
  test eax, eax
  js exit_error
  jz .close_pipe              ; Salta direttamente alla chiusura pipe
  sub edx, eax
  jnz .skip_loop

  ; Ciclo di copia: legge l'input residuo e lo scrive nella pipe del figlio
.write_loop:
  push 3                      ; SYS_read
  pop eax
  mov ebx, edi                ; input fd
  mov ecx, buf
  mov edx, 512
  int 0x80
  test eax, eax
  js exit_error
  jz .close_pipe              ; EOF raggiunto

  mov edx, eax                ; byte letti
  push 4                      ; SYS_write
  pop eax
  mov ebx, [pipefd+4]         ; Scrive sul lato write della pipe
  mov ecx, buf
  int 0x80
  jmp .write_loop

.close_pipe:
  ; Chiude il lato di scrittura della pipe di input. 
  ; Questo invia finalmente l'EOF a zcat!
  push 6                      ; SYS_close
  pop eax
  mov ebx, [pipefd+4]         ; Chiude la pipe -> manda EOF a zcat
  int 0x80

  ; Chiude l'input iniziale se era un file aperto
  test edi, edi
  jz .wait_child
  push 6                      ; SYS_close
  pop eax
  mov ebx, edi                ; Chiude l'input fd d'origine
  int 0x80

.wait_child:
  ; Attende che il figlio (zcat) finisca di decomprimere tutto nel memfd
  ; sys_waitpid(pid, status, options) -> sys_waitpid(-1, 0, 0) o sul pid specifico in EAX
  ; Per semplicità e compattezza passiamo -1 (attendi un figlio qualsiasi)
  mov ebx, -1
  xor ecx, ecx
  xor edx, edx
  push 7                      ; SYS_waitpid
  pop eax
  int 0x80

execute:
  ; Ripristina argv[0]
  mov eax, filename
  mov [esi], eax              ; ESI contiene il puntatore ad argv originario

  ; Esecuzione dal memfd, che ora contiene l'intero binario spacchettato
  ; Ripristino pulito dello stack prima dell'execveat per evitare EFAULT
  mov eax, 358                ; SYS_execveat
  mov ebx, [memfd_saved]      ; EBX = memfd validato
  push 0                      ; push stringa vuota "" nello stack
  mov ecx, esp                ; ECX = punta a ""
  mov edx, esi                ; EDX = argv originale intatto (ripristinato in ESI)
  mov esi, ebp                ; ESI = envp (estratto da EBP)
  mov edi, 0x1000             ; EDI = AT_EMPTY_PATH flag
  int 0x80
  jmp exit_error

  ; ============================================================================
  ; CHILD PROCESS (Esegue zcat)
  ; ============================================================================
child:
  ; Chiude il lato scrittura della pipe ereditato dal padre
  push 6                      ; SYS_close
  pop eax
  mov ebx, [pipefd+4]         ; Chiude il lato di scrittura della pipe di input!
  int 0x80

  ; dup2: collega il lato lettura della pipe allo STDIN (0)
  push 63                     ; SYS_dup2
  pop eax
  mov ebx, [pipefd]           ; Chiude il lato di lettura della pipe di output!
  xor ecx, ecx                ; 0 = stdin
  int 0x80

  ; dup2: collega il MEMFD direttamente allo STDOUT (1) di zcat!
  push 63                     ; SYS_dup2 (stdout)
  pop eax
  mov ebx, [memfd_saved]
  push 1
  pop ecx                     ; 1 = stdout
  int 0x80

  ; Esecuzione di zcat semplice (zcat -)
  push 11                     ; SYS_execve
  pop eax
  mov ebx, zcat_path
  push 0
  push dash_arg
  push zcat_path
  mov ecx, esp
  xor edx, edx
  int 0x80

exit_error:
  push 1                      ; SYS_exit
  pop eax
  xor ebx, ebx
  inc ebx                     ; Exit code 1
  int 0x80

; ==============================================================================
; DATA SECTION
; ==============================================================================
filename:   db "uskexz", 0
zcat_path:  db "/bin/zcat", 0
dash_arg:   db "-", 0

; ==============================================================================
; PADDING: Allineato esattamente a 512 byte (come da richiesta skip)
; ==============================================================================
file_end:
times (512 - ($ - $$)) db 0

; ==============================================================================
; BSS SECTION (Solo in RAM, allineato a 512 bytes)
; ==============================================================================
bss_start equ $$ + 512

pipefd:      equ bss_start + 0   ; 2 dwords (read, write)
memfd_saved: equ pipefd + 8      ; memfd fd
buf:         equ memfd_saved + 4
bss_end:     equ buf + 512

