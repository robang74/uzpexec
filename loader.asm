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
    dd _end - elf_header        ; p_filesz (Dimensione del codice nel file)
    dd _end - elf_header        ; p_memsz (Dimensione del codice in memoria)
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

    ; 2. write(mfd, payload_start, payload_size)
    mov eax, 4                  ; SYS_write
    mov ebx, edi                ; Il nostro memfd
    mov ecx, payload_start      ; Puntatore all'inizio del payload gzip/binario allegato sotto
    mov edx, payload_end - payload_start ; Lunghezza esatta del payload
    int 0x80

    ; 3. execveat(mfd, "", argv, envp, AT_EMPTY_PATH)
    ; Questa syscall (numero 358 a 32-bit) permette di eseguire direttamente un FD
    mov eax, 358                ; SYS_execveat
    mov ebx, edi                ; Il nostro memfd
    mov ecx, empty_string       ; Path vuoto "", perché usiamo AT_EMPTY_PATH
    ; Per brevità in questo schema passiamo argv e envp ereditati o nulli
    xor edx, edx                ; argv = NULL (o puntatore valido se vuoi inoltrare gli argomenti)
    xor esi, esi                ; envp = NULL
    mov edi, 0x1000             ; AT_EMPTY_PATH (Flag obbligatorio per dire al kernel di ignorare il path)
    int 0x80

exit_error:
    mov eax, 1                  ; SYS_exit
    mov ebx, 1                  ; Exit code 1
    int 0x80

; ==============================================================================
; SEZIONE DATI COMPATTA (In coda al codice)
; ==============================================================================
filename:     db "u", 0
empty_string: db 0

; ==============================================================================
; PAYLOAD ALLEGATO (Il tuo binario umkaos32 scompattato o la pipe)
; ==============================================================================
payload_start:
    ; Qui il tuo script di build (o dd) concatenerà fisicamente i byte 
    ; del binario pronto da eseguire.
payload_end:

_end:
