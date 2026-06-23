; ==============================================================================
; (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
;     Coded with the support of Kimi and then Gemini for the size reduction
; ==============================================================================
; Fix dell'architettura a 2 pipe per zcat:
; 1. Legge se stesso (da argv[0] o stdin)
; 2. Scarta i primi 512 byte (skip dell'header/loader)
; 3. Invia il resto a zcat tramite pipe
; 4. Legge l'output spacchettato da zcat e lo carica in un memfd anonimo
; 5. Esegue il codice dal memfd
; ==============================================================================
; Ottimizzazione a Singola Pipe con Scrittura Diretta, Architettura:
; - 1 pipe (input), fork, child scrive direttamente su memfd via dup2.
; ==============================================================================
; Ottimizzazione: versione ad Altissima Efficienza (Zero Pipes)
; Supporta in modo trasparente sia file (argv[0]) che stdin senza allocare pipe.
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
  mov [memfd_saved], eax      ; Salviamo il memfd nel BSS

  ; 3. Skip del blocco iniziale da 512 byte direttamente dal descrittore EDI
  mov ecx, buf
  mov edx, 512
.skip_loop:
  push 3                      ; SYS_read
  pop eax
  mov ebx, edi                ; input fd
  int 0x80
  test eax, eax
  js exit_error
  jz exit_error               ; EOF prematuro se il file è minore di 512 byte
  sub edx, eax
  jnz .skip_loop

  ; 4. Fork (Senza aver creato nessuna pipe!)
  push 2                      ; SYS_fork
  pop eax
  int 0x80
  test eax, eax
  jz child                    ; Se EAX == 0, vai al processo figlio

  ; ============================================================================
  ; PARENT PROCESS
  ; ============================================================================
  ; Il padre deve solo attendere che il figlio (zcat) finisca di decomprimere
; mov ebx, -1                ; RAF: -2 bytes
  xor ebx, ebx
  dec ebx
  xor ecx, ecx
  xor edx, edx
  push 7                      ; SYS_waitpid
  pop eax
  int 0x80

  ; Chiude l'input iniziale se era un file aperto (nel padre non serve più)
  test edi, edi
  jz execute
  push 6                      ; SYS_close
  pop eax
  mov ebx, edi                ; Chiude l'input fd d'origine
  int 0x80

execute:
  ; Configura argv[0] ed esegue dal memfd
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
  ; CHILD PROCESS (Esegue zcat collegando i descrittori esistenti)
  ; ============================================================================
child:
  ; dup2: collega l'input fd (già posizionato a +512 byte) allo STDIN (0) di zcat
  ; Nota: se EDI era già 0 (stdin d'origine), dup2(0, 0) è un no-op sicuro del kernel
  push 63                     ; SYS_dup2
  pop eax
  mov ebx, edi
  xor ecx, ecx                ; 0 = stdin
  int 0x80

  ; dup2: collega il MEMFD direttamente allo STDOUT (1) di zcat
  push 63                     ; SYS_dup2
  pop eax
  mov ebx, [memfd_saved]
  push 1
  pop ecx                     ; 1 = stdout
  int 0x80

  ; Esecuzione pulita di zcat semplice (zcat -)
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
filename:   db "uzexec", 0
zcat_path:  db "/bin/zcat", 0
dash_arg:   db "-", 0

; ==============================================================================
; PADDING: Allineato esattamente a 512 byte (come da richiesta skip)
; ==============================================================================
file_end:
times (512 - ($ - $$)) db 0   ; Padding a 512 byte impostato come limite

; ==============================================================================
; BSS SECTION (Solo in RAM, allineato a 512 bytes)
; ==============================================================================
bss_start equ $$ + 512

memfd_saved: equ bss_start + 0  ; Unica variabile necessaria oltre al buffer
buf:         equ memfd_saved + 4
bss_end:     equ buf + 512

