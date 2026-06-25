; ==============================================================================
;
; (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT+1 license
;
;     MIT+1: due to the extreme nature of this software, an extra clause is
;            added to the standard MIT license, which forbids everyone to
;            remove or change the authorship string also from the binary.
;
; ==============================================================================

BITS 32
org 0x08048000

ehdr:                               ; Elf32_Ehdr
    db 0x7F, "ELF", 1, 1, 1, 0      ; e_ident
    times 8 db 0
    dw 2                            ; e_type (ET_EXEC)
    dw 3                            ; e_machine (EM_386)
    dd 1                            ; e_version
    dd _start                       ; e_entry
    dd phdr - ehdr                  ; e_phoff
    dd 0                            ; e_shoff
    dd 0                            ; e_flags
    dw ehdr_size                    ; e_ehsize
    dw phdr_size                    ; e_phentsize
    dw 1                            ; e_phnum
    dw 0                            ; e_shentsize
    dw 0                            ; e_shnum
    dw 0                            ; e_shstrndx
ehdr_size equ $ - ehdr

phdr:                               ; Elf32_Phdr
    dd 1                            ; p_type (PT_LOAD)
    dd 0                            ; p_offset
    dd ehdr                         ; p_vaddr
    dd ehdr                         ; p_paddr
    dd _end - ehdr                  ; p_filesz
    dd _end_bss - ehdr              ; p_memsz
    dd 7                            ; p_flags (RWE)
    dd 0x1000                       ; p_align
phdr_size equ $ - phdr

_start:
    ; 1. Open our own executable binary to access the appended payload
    mov eax, 5                      ; sys_open
    mov ebx, [esp + 4]              ; argv[0] from stack frame
    xor ecx, ecx                    ; O_RDONLY = 0
    int 0x80
    mov ebx, eax                    ; ebx = file descriptor

    ; Seek past the loader header exactly to the payload offset
    mov eax, 19                     ; sys_lseek
    mov ecx, 512                    ; offset = 512 bytes
    xor edx, edx                    ; SEEK_SET = 0
    int 0x80

    ; Read the entire compressed payload chunk into memory staging area
    mov eax, 3                      ; sys_read
    mov ecx, comp_buf
    mov edx, 2 * 1024 * 1024        ; Support up to 2MB compressed payload
    int 0x80

    ; Close our file descriptor
    mov eax, 6                      ; sys_close
    int 0x80

    ; 2. Create the target memfd execution sandbox
    mov eax, 356                    ; sys_memfd_create
    mov ebx, name_str
    xor ecx, ecx                    ; flags = 0
    int 0x80
    mov [memfd], eax                ; store memfd descriptor

    ; 3. Setup Decompression Engine Pointers & States
    mov esi, comp_buf               ; Source base
    mov ecx, [esi]                  ; Load 32-bit tag_stream_size
    add esi, 4                      ; Move esi to the start of the Tag Stream
    
    mov ebx, esi
    add ebx, ecx                    ; Move ebx to the start of the Data Stream
    
    mov edi, decomp_buf             ; Output extraction buffer
    xor ebp, ebp                    ; Clear bit-tag container register

.decomp_loop:
    ; Read next control bit (1 = Literal, 0 = Match)
    add ebp, ebp
    jnz .bit_ready
    mov ebp, [esi]                  ; Refill 16-bit word from stream
    add esi, 2
    stc                             ; Set carry flag as a sentinel bit
    adc ebp, ebp                    ; Shift-inject sentinel
.bit_ready:
    jc .literal

.match:
    ; Decode Elias Gamma encoded length value
    xor ecx, ecx                    ; count = 0
.gamma_count:
    add ebp, ebp
    jnz .g_bit1_ready
    mov ebp, [esi]
    add esi, 2
    stc
    adc ebp, ebp
.g_bit1_ready:
    jc .gamma_value
    inc ecx
    jmp .gamma_count

.gamma_value:
    mov eax, 1                      ; val = 1
.gamma_val_loop:
    jecxz .gamma_done
    add ebp, ebp
    jnz .g_bit2_ready
    mov ebp, [esi]
    add esi, 2
    stc
    adc ebp, ebp
.g_bit2_ready:
    adc eax, eax                    ; Shift left and inject incoming bit
    dec ecx
    jmp .gamma_val_loop
.gamma_done:
    inc eax                         ; match_len = decoded_val + 1

    ; Read 16-bit sliding back-reference offset
    movzx edx, word [ebx]
    add ebx, 2
    
    test edx, edx                   ; offset == 0 dictates End Of Stream (EOS)
    jz .decomp_finished

    ; Process string match back-reference copy
    push esi
    mov esi, edi
    sub esi, edx                    ; back pointer calculation
    mov ecx, eax                    ; match length
    rep movsb
    pop esi
    jmp .decomp_loop

.literal:
    ; Process standalone raw byte copy
    mov al, [ebx]
    inc ebx
    mov [edi], al
    inc edi
    jmp .decomp_loop

.decomp_finished:
    ; 4. Stream uncompressed binary buffer to the memfd container
    mov ecx, edi
    sub ecx, decomp_buf             ; ecx = total size in bytes
    
    mov eax, 4                      ; sys_write
    mov ebx, [memfd]
    mov edx, ecx
    mov ecx, decomp_buf
    int 0x80

    ; 5. Execute payload directly via sys_execveat
    mov eax, 358                    ; sys_execveat
    mov ebx, [memfd]
    mov ecx, empty_str
    lea edx, [esp + 4]              ; pass unmodified argv context
    mov esi, [esp]                  ; argc context
    lea esi, [esp + 4 + esi * 4 + 4]; envp array mapping
    mov edi, 0x1000                 ; AT_EMPTY_PATH flag
    mov ecx, empty_str
    int 0x80

    ; Hard exit fallback if execution routing breaks
    mov eax, 1                      ; sys_exit
    mov ebx, 1
    int 0x80

name_str:  db "b4l", 0
empty_str: db 0

; Force strict 512-byte structural padding boundary alignment
times 512 - ($ - ehdr) db 0
_end:

SECTION .bss
memfd:       resd 1
comp_buf:    resb 2 * 1024 * 1024   ; Staging area for input payload (2MB max)
decomp_buf:  resb 8 * 1024 * 1024   ; Unpacked space allocation (8MB max)
_end_bss:
