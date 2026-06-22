BITS 32

org 0x08048000

; ==============================================================================
; INTESTAZIONE ELF32 (Scritta a mano per azzerare l'overhead)
; ==============================================================================
elf_header:
    db 0x7F, 'ELF', 1, 1, 1, 0  ; e_ident (Magic, Class 32bit, Data LSB, Version)
    times 8 db 0                ; Padding di e_ident
    dw 2                        ; e_type (Executable)
    dw 3                        ; e_machine (Intel 80386)
    dd 1                        ; e_version
    dd code_start               ; e_entry (Il punto di inizio del nostro codice)
    dd phdr - elf_header        ; e_phoff (Offset della Program Header Table)
    dd 0                        ; e_shoff (Nessuna Section Header Table, risparmio byte!)
    dd 0                        ; e_flags
    dw 52                       ; e_ehsize (Dimensione di questa intestazione)
    dw 32                       ; e_phentsize (Dimensione della riga Program Header)
    dw 1                        ; e_phnum (Un solo segmento necessario)
    dw 0, 0, 0                  ; Info su sezioni (azzerate)

phdr:
    dd 1                        ; p_type (PT_LOAD - Segmento da caricare)
    dd 0                        ; p_offset
    dd 0x08048000               ; p_vaddr (Indirizzo virtuale in memoria)
    dd 0x08048000               ; p_paddr
    dd file_end - elf_header    ; p_filesz (Dimensione del codice nel file)
    dd bss_end - elf_header     ; p_memsz (Dimensione del codice in memoria)
    dd 7                        ; p_flags (R+W+X - Lettura, Scrittura ed Esecuzione)
    dd 0x1000                   ; p_align (Allineamento standard di pagina)

; ==============================================================================
; IL CODICE DEL LOADER (Inizio esecuzione)
; ==============================================================================
code_start:
    ; 1. mfd = memfd_create("u", MFD_CLOEXEC)
    ; Nota: A 32-bit il numero della syscall memfd_create è 356
    mov eax, 356                ; SYS_memfd_create
    mov ebx, filename           ; Puntatore al nome del file anonimo (es: "u")
    mov ecx, 1                  ; MFD_CLOEXEC (Evita leak del FD a processi figli non voluti)
    int 0x80                    ; Chiamata al kernel Linux (A 32-bit si usa int 0x80)
    test eax, eax
    js exit_error               ; Se il valore è negativo, c'è un errore (es: kernel troppo vecchio)
    mov edi, eax                ; Salva il File Descriptor ritornato in EDI per dopo

read_block_setup:
    ; Prepariamo i registri per accumulare un blocco atomico da 512 byte
    mov ecx, buffer             ; Puntatore corrente nel buffer
    mov edx, 512                ; Byte rimasti da leggere per questo blocco

read_loop:
    ; 2. read(0, buffer, 512) legge da STDIN a blocchi da 512 byte (stile dd)
    mov eax, 3                  ; SYS_read
;   mov ebx, 0                  ; STDIN
    xor ebx, ebx                ; STDIN is 0 = a^a (but shorter code)
    int 0x80

    test eax, eax
    jz flush_and_execute        ; EAX == 0 -> EOF. Scrivi l'ultimo residuo ed esegui!
    cmp eax, -4                 ; EAX == -EINTR (Interrupted system call)
    je read_loop                ; Se interrotto da segnale, ignora e riprova la read
    js exit_error               ; Qualsiasi altro errore negativo (< 0) -> Muori.

    ; Se siamo qui, abbiamo letto X byte (in EAX)
    sub edx, eax                ; Sottrai i byte letti da quelli mancanti (512 - X)
    add ecx, eax                ; Sposta il puntatore del buffer in avanti per la prossima lettura
    test edx, edx
    jnz read_loop               ; Se edx > 0, il blocco da 512 non è completo. Continua a leggere!

    ; --- IL BLOCCO DA 512 BYTE È ORA COMPLETO ---
    ; Scriviamo l'intero blocco nel memfd
    mov eax, 4                  ; SYS_write
    mov ebx, edi                ; Il nostro memfd
    mov ecx, buffer             ; Riparte dall'inizio del buffer
    mov edx, 512                ; Scrive 512 byte esatti
    int 0x80
    js exit_error

    jmp read_block_setup        ; Reset e passa al prossimo blocco da 512 byte

flush_and_execute:
    ; Se la pipe finisce ma avevamo accumulato un blocco parziale in RAM,
    ; dobbiamo fare il flush dei byte residui prima di lanciare l'eseguibile.
    mov eax, 512
    sub eax, edx                ; Calcola quanti byte effettivi c'erano nel blocco parziale
    jz execute_now              ; Se zero, il blocco era perfettamente allineato. Passa all'esecuzione.

    mov edx, eax                ; EDX = byte residui
    mov eax, 4                  ; SYS_write
    mov ebx, edi                ; memfd
    mov ecx, buffer             ; Inizio del buffer
    int 0x80
    js exit_error

execute_now:
    ; 4. Setup minimo di sicurezza dello stack per argv
    ; Evita il rifiuto ENOEXEC del kernel iniettando un finto argv[0]
    push 0                      ; Terminatore NULL per envp
    push 0                      ; Terminatore NULL per argv
    mov ecx, esp                ; ECX punta alla struttura [filename, NULL]
    mov eax, filename
    push eax                    ; argv[0] = filename

    ; Ora lo stack è cambiato, salviamo il NUOVO puntatore dello stack in EDX
    mov edx, esp                ; EDX punta alla struttura [filename, NULL]
    xor esi, esi                ; envp = NULL

    ; 5. execveat(mfd, "", argv, envp, AT_EMPTY_PATH)
    mov eax, 358                ; SYS_execveat
    mov ebx, edi                ; Il nostro memfd
    
    ; Per fare ordine coi registri della syscall execveat(ebx, ecx, edx, esi, edi):
    ; EBX = mfd  (edi)
    ; ECX = ""   (preservato dal mov ecx, esp di prima)
    ; EDX = argv (spostato in edx anziché ecx!)
    ; ESI = envp (esi)
    ; EDI = AT_EMPTY_PATH (0x1000)
    mov edi, 0x1000             ; AT_EMPTY_PATH
    int 0x80

exit_error:
    mov eax, 1                  ; SYS_exit
    mov ebx, 1                  ; Exit code 1
    int 0x80

; ==============================================================================
; SEZIONE DATI COMPATTA (In coda al codice)
; ==============================================================================
filename:     db "uldr", 0

file_end:                       ; Fine fisica del file binario!

; ==============================================================================
; SEZIONE BSS NON INIZIALIZZATA (Esiste SOLO in RAM, zero byte su disco)
; ==============================================================================
absolute_address equ $
buffer equ absolute_address + 4 ; Il buffer inizia subito dopo la fine del file
bss_end equ buffer + 512         ; Riserva 512 byte per il buffer in RAM

