; ==============================================================================
;
; (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT+1 license
;
; ==============================================================================

BITS 32
org 0x08048000

; ==============================================================================
; ELF32 HEADER (Micro-Loader a 32-bit, Teeny ELF)
; ==============================================================================
elf_header:
  db 0x7F, 'ELF', 1, 1, 1, 0  
  times 8 db 0                
  dw 2                        
  dw 3                        
  dw 1                        
  dd main_start               
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
; upexec CODE (Execution starts here)
; ==============================================================================
main_start:
  ; Salvataggio dei vettori iniziali dallo stack [cite: 76, 77]
  pop eax                       ; argc [cite: 78]
  mov esi, esp                  ; ESI = argv [cite: 79]
  lea ebp, [esi+eax*4+4]        ; EBP = envp [cite: 80]

  ; 0. Creazione incondizionata del memfd [cite: 14]
  mov eax, 356                  ; SYS_memfd_create [cite: 16]
  mov ebx, filename             ; Nome del file fittizio [cite: 17]
  push 1                        ; MFD_CLOEXEC [cite: 18]
  pop ecx
  int 0x80
  mov [memfd], eax              ; Salva l'FD del memfd [cite: 13]

  ; 1. Tentativo di apertura di argv[0] [cite: 83]
  mov ebx, [esi]                ; EBX = argv[0] [cite: 80]
  xor ecx, ecx                  ; O_RDONLY
  push 5                        ; SYS_open
  pop eax
  int 0x80
  mov edi, eax                  ; Sposta l'FD in EDI per preservarlo

  ; 2. Verifica se l'apertura ha avuto successo tramite lettura dell'header
  mov ecx, buf
  mov edx, 512                  ; Legge esattamente l'ampiezza dell'header [cite: 83]
.skip_loop:
  push 3                        ; SYS_read
  pop eax
  mov ebx, edi                  ; input fd
  int 0x80
  test eax, eax
  js .stdin_fallback            ; Se errore (es. non è un file apribile), passa a STDIN
  jz .stdin_fallback            ; Se EOF prematuro, passa a STDIN
  sub edx, eax
  jnz .skip_loop
  jmp .fork_now                 ; Successo: EDI contiene l'FD del file pronto (+512 byte)

.stdin_fallback:
  xor edi, edi                  ; EDI = 0 (STDIN) [cite: 15, 84]

.fork_now:
  ; 3. Fork del processo [cite: 14]
  push 2                        ; SYS_fork [cite: 19]
  pop eax
  int 0x80
  test eax, eax
  jz child                      ; Se figlio, salta al blocco child [cite: 20]

  ; ============================================================================
  ; PARENT PROCESS
  ; ============================================================================
parent:
  ; Il genitore attende che il figlio (zcat) completi il dump nel memfd [cite: 21]
  xor ecx, ecx
  xor edx, edx
  xor ebx, ebx
  dec ebx                       ; -1 [cite: 22]
  push 7                        ; SYS_waitpid [cite: 23]
  pop eax
  int 0x80

  ; Se abbiamo aperto un file reale, chiudiamo l'FD non più necessario
  test edi, edi
  jz .rewind_memfd
  push 6                        ; SYS_close [cite: 46]
  pop eax
  mov ebx, edi
  int 0x80

.rewind_memfd:
  ; Rewind del memfd all'inizio per lo sniffing dei magic bytes [cite: 10, 24]
  push 19                       ; SYS_lseek [cite: 24]
  pop eax
  mov ebx, [memfd]              ; [cite: 25]
  xor ecx, ecx                  ; offset = 0 [cite: 25]
  xor edx, edx                  ; SEEK_SET = 0 [cite: 26]
  int 0x80

  ; Lettura dei primi 4 byte [cite: 10, 27]
  push 3                        ; SYS_read [cite: 27]
  pop eax
  mov ecx, buf                  ; [cite: 28]
  push 4                        ; [cite: 28]
  pop edx                       ; count = 4 [cite: 28]
  int 0x80

  ; Verifica la firma dell'ELF (\x7FELF) [cite: 10, 29]
  cmp dword [buf], 0x464c457f   ; Match Little-Endian [cite: 29]
  jz .execute_elf               ; Se ELF, salta alla transizione diretta

  ; ----------------------------------------------------------------------------
  ; SCRIPT MODE: Gestione interpretata via /bin/sh [cite: 30]
  ; ----------------------------------------------------------------------------
  ; Riporta il memfd a 0 affinché la shell possa leggerlo dall'inizio [cite: 31]
  push 19                       ; SYS_lseek [cite: 31]
  pop eax
  mov ebx, [memfd]
  xor ecx, ecx
  xor edx, edx
  int 0x80

  ; Collega il memfd allo STDIN (fd 0) per l'interprete [cite: 33]
  push 63                       ; SYS_dup2 [cite: 33]
  pop eax
  mov ebx, [memfd]
  xor ecx, ecx                  ; 0 = stdin [cite: 34]
  int 0x80

  ; Esecuzione dell'interprete /bin/sh [cite: 35]
  mov ebx, do_sh_path           ; [cite: 35]

  ; Manipolazione dello stack per ereditare i parametri [cite: 37]
  mov dword [esi - 4], ebx      ; Sovrascrive lo slot argc con "/bin/sh" [cite: 37]
  mov dword [esi], dash_sarg    ; Mette "-s" in argv[0] [cite: 38]
  lea ecx, [esi - 4]            ; ECX punta al nuovo vettore [cite: 39]

  push 11                       ; SYS_execve [cite: 43]
  pop eax
  mov edx, ebp                  ; envp intatto [cite: 44]
  int 0x80
  jmp exit_error

  ; ----------------------------------------------------------------------------
  ; ELF BINARY MODE: Esecuzione diretta nativa [cite: 45]
  ; ----------------------------------------------------------------------------
.execute_elf:
  mov eax, 358                  ; SYS_execveat [cite: 47]
  mov ebx, [memfd]              ; EBX = FD del memfd [cite: 48]
  push 0                        ; Stringa vuota "" su stack [cite: 49]
  mov ecx, esp                  ; ECX punta a "" [cite: 50]
  mov edx, esi                  ; EDX = argv originario [cite: 51]
  mov esi, ebp                  ; ESI = envp [cite: 52]
  mov edi, 0x1000               ; EDI = AT_EMPTY_PATH [cite: 53]
  int 0x80
  jmp exit_error                

; ============================================================================
; CHILD PROCESS
; ============================================================================
child:
  ; 1st dup2: Direziona l'input (file posizionato o STDIN) nello STDIN del child [cite: 55]
  push 63                       ; SYS_dup2 [cite: 55]
  pop eax
  mov ebx, edi                  ; FD di input [cite: 56]
  xor ecx, ecx                  ; 0 = stdin [cite: 57]
  int 0x80                      

  ; 2nd dup2: Connette l'output del memfd allo STDOUT del child [cite: 59]
  push 63                       ; SYS_dup2 [cite: 59]
  pop eax
  mov ebx, [memfd]              ; Scrive nel memfd condiviso [cite: 60]
  inc ecx                       ; 1 = stdout [cite: 61]
  int 0x80
  test eax, eax
  js exit_error

  ; Esecuzione di zcat con l'argomento "-f" sempre attivo [cite: 62]
  push 11                       ; SYS_execve [cite: 62]
  pop eax
  mov ebx, zcat_path            ; [cite: 63]
  push 0                        ; Fine envp/argv [cite: 63]
  push force_arg                ; Forza il trattamento trasparente ("-f") [cite: 64]
  push zcat_path                ; argv[0] per il tool
  mov ecx, esp                  ; Costruisce il vettore degli argomenti
  xor edx, edx                  ; envp nullo
  int 0x80

; ============================================================================
exit_error:
  ; Stampa della notifica d'errore/copyright [cite: 91]
  push zcat_path - copy_vers    ; [cite: 92]
  pop edx                       ; [cite: 93]
  mov ecx, copy_vers            ; [cite: 94]
  mov byte [ecx + edx - 1], 10  ; [cite: 95]
  push 4                        ; SYS_write [cite: 96]
  pop eax
  push 2                        ; stderr [cite: 97]
  pop ebx
  int 0x80

  push 1                        ; Exit code 1 [cite: 98, 99]
  pop eax
  int 0x80

; ==============================================================================
; COMPACT DATA SECTION (appended to code)
; ==============================================================================
copy_vers:  db "(c) github/robang74 v0.87 "                       ; [cite: 106, 107]
filename :  db      "uzpexec", 0                                  ; [cite: 107, 108]
zcat_path:  db         "/bin/zcat",  0,0,0, 0,0,0,0, 0,0,0,0, 0   ; [cite: 108, 109]
do_sh_path: db "/bin/sh", 0                                       ; [cite: 66]
dash_sarg:  db "-s", 0                                            ; [cite: 70]
force_arg:  db "-f", 0                                            ; [cite: 118]
eof_tests:  db "U238"                                             ; [cite: 111, 112]

; ==============================================================================
; PADDING: Allineamento perfetto a 512 byte [cite: 121]
; ==============================================================================
file_end:                       
times (512 - ($ - $$)) db 0     ; [cite: 123]

; ==============================================================================
; BSS SECTION (RAM temporary storage) [cite: 124]
; ==============================================================================
bss_start equ $$ + 512

memfd:    equ bss_start + 0     ; [cite: 125]
buf:      equ memfd + 4         ; [cite: 126]
bss_end:  equ buf + 512         ; [cite: 126]
