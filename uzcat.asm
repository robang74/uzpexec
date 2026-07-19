; Input: EAX = magic number letto dal file (primi 4 byte)
; Output: ESI = puntatore a stringa "/bin/...cat\0" trovata
;         ZF = 1 se trovata, 0 se fallback

find_decompressor:
    mov ecx, magic_count
    mov esi, magics
    mov edi, paths

.loop:
    cmp eax, [esi]
    je .found
    add esi, 4
    add edi, 16
    loop .loop

    mov eax, catcmd         ; fallback
    ret

.found:
    mov eax, edi            ; EAX = stringa trovata o fallback
    ret

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
