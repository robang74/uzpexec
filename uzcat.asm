; Input: EAX = magic number letto dal file (primi 4 byte)
; Output: ESI = puntatore a stringa "/bin/...cat\0" trovata
;         ZF = 1 se trovata, 0 se fallback

find_decompressor:
    mov ecx, magic_count        ; 9 iterazioni
    mov esi, magics             ; ESI = vettore magic
    mov edi, paths              ; EDI = vettore stringhe

.loop:
    cmp eax, [esi]              ; confronta magic
    je .found
    add esi, 4                  ; prossimo magic
    add edi, 16                 ; prossima stringa
    loop .loop

.fallback
    sub esp, 16                 ; riserva spazio
    push catcmd
    jmp .dowork

.found:
    mov esi, edi                ; ESI = puntatore a stringa trovata

    ; copia stringa da ESI su stack
    mov edi, esp
    sub esp, 16                 ; riserva spazio
    
    push esi
    push edi
    mov ecx, 16

.dowork
    rep movsb                   ; copia 16 byte (inclusi padding 0)
    pop edi
    pop esi
    
    ; ora [esp] contiene il path, EDI punta al byte dopo

; ------------------------------------------------------------------------------
section .data

; Vettore magic numbers (9 × 4 byte)
magics:
    dd 0x1f8b0800       ; [0] gzip
    dd 0xfd377a58       ; [1] xz
    dd 0x4c5a4950       ; [2] lzip
    dd 0x425a6839       ; [3] bzip2
    dd 0x184d2204       ; [4] lz4
    dd 0x894c5a4f       ; [5] lzop
    dd 0x6c7a6673       ; [6] lzfs
    dd 0x28b52ffd       ; [7] zstd
    dd 0x4c525a49       ; [8] lrzip
magic_count equ 9

; Vettore stringhe (9 × 16 byte), padding con 0
paths:
    db "/bin/zcat", 0, 0, 0, 0, 0, 0    ; 16 byte
    db "/bin/xzcat", 0, 0, 0, 0, 0       ; 16 byte
    db "/bin/lzcat", 0, 0, 0, 0, 0       ; 16 byte
    db "/bin/bzcat", 0, 0, 0, 0, 0       ; 16 byte
    db "/bin/lz4cat", 0, 0, 0, 0         ; 16 byte
    db "/bin/lzopcat", 0, 0, 0           ; 16 byte
    db "/bin/lzfscat", 0, 0, 0           ; 16 byte
    db "/bin/zstdcat", 0, 0, 0           ; 16 byte
    db "/bin/lrzipcat", 0, 0             ; 16 byte

catcmd:
    db "/bin/cat", 0
