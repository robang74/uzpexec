; ==============================================================================
;
; (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT+1 license
;
;     MIT+1: due to the extreme nature of this software, an extra clause is
;            added to the standard MIT license, which forbids everyone to
;            remove or change the authorship string also from the binary.
;
; ==============================================================================
;
; Single-Process Universal zRLE Architecture:
; - 1. Reads itself (from argv[0] or stdin)
; - 2. Discards the first 512 bytes if opening itself via file path
; - 3. Creates an anonymous memfd (without MFD_CLOEXEC to allow script interpretation)
; - 4. Decodes the compressed zRLE payload directly into the memfd
; - 5. Replaces process image via execveat. Kernel auto-detects ELF vs script.
;
; ==============================================================================

BITS 32
org 0x08048000

; ==============================================================================
; ELF32 HEADER
; ==============================================================================
elf_header:
  db 0x7F, 'ELF', 1, 1, 1, 0  ; e_ident
  times 8 db 0                ; Padding
  dw 2                        ; e_type (Executable)
  dw 3                        ; e_machine (Intel 80386)
  dd 1                        ; e_version
  dd main_start               ; e_entry
  dd phdr - elf_header        ; e_phoff
  dd 0                        ; e_shoff
  dd 0                        ; e_flags
  dw 52                       ; e_ehsize
  dw 32                       ; e_phentsize
  dw 1                        ; e_phnum
  dw 0, 0, 0                  ; Section info

phdr:
  dd 1                        ; p_type (PT_LOAD)
  dd 0                        ; p_offset
  dd 0x08048000               ; p_vaddr
  dd 0x08048000               ; p_paddr
  dd file_end - elf_header    ; p_filesz
  dd bss_end - elf_header     ; p_memsz
  dd 7                        ; p_flags (R+W+X)
  dd 0x1000                   ; p_align

; ==============================================================================
; upexec CODE
; ==============================================================================
main_start:
  pop eax                     ; argc
  mov esi, esp                ; ESI = argv
  mov [argv_ptr], esi         ; Persist original argv base pointer
  lea ebp, [esi+eax*4+4]      ; EBP = envp

  ; 1. Checking argv[0] to open input
  mov ebx, [esi]
  test ebx, ebx
  jz .stdin
  cmp byte [ebx], 0
  jz .stdin

  mov edx, ebx
.find_end:
  inc edx
  cmp byte [edx], 0
  jnz .find_end

.backtrack:
  cmp edx, ebx
  je .do_strcmp
  dec edx
  cmp byte [edx], '/'
  jne .backtrack
  inc edx

.do_strcmp:
  mov ecx, filename

.strcmp_loop:
  mov al, [edx]
  mov ah, [ecx]
  cmp al, ah
  jne .not_uzpexec
  test al, al
  jz .stdin
  inc edx
  inc ecx
  jmp .strcmp_loop

.not_uzpexec:
  xor ecx, ecx                  ; O_RDONLY
  push 5                        ; SYS_open
  pop eax
  int 0x80
  mov edi, eax                  ; EDI = input fd

  ; Skip 512-byte block
  mov ecx, buf
  mov edx, 512
.skip_loop:
  push 3                        ; SYS_read
  pop eax
  mov ebx, edi
  int 0x80
  test eax, eax
  jle exit_error
  sub edx, eax
  jnz .skip_loop
  jmp .memfd

.stdin:
  xor edi, edi                  ; EDI = stdin

.memfd:
  mov ebx, filename             ; Name string pointer
  mov eax, 356                  ; SYS_memfd_create
  
  ; CRITICAL CHANGE FOR SCRIPTS:
  ; We clear ECX (flags = 0). We do NOT use MFD_CLOEXEC.
  ; This keeps the fd alive so interpreters (/bin/sh) can access /dev/fd/N
  xor ecx, ecx                  
  xor edx, edx                  
  int 0x80
  mov [memfd], eax

; ==============================================================================
; STREAM DECOMPRESSOR ENGINE
; ==============================================================================
decompress_stream:
  xor ecx, ecx                  ; Force immediate initial block read
.loop:
  call fetch_byte
  jc .execute                   ; Carry Set -> EOF, branch to execution

  cmp al, 0xAA                  ; RLE Magic Marker check
  jne .literal

  call fetch_byte
  jc exit_error                 ; Trap truncated run length
  mov dl, al                    ; DL = loop repetition counter

  call fetch_byte
  jc exit_error                 ; Trap truncated payload value

.rle_write:
  call write_byte
  dec dl
  jnz .rle_write
  jmp .loop

.literal:
  call write_byte
  jmp .loop

; ==============================================================================
; EXECUTION STAGE
; ==============================================================================
.execute:
  ; Close initial stream input if it wasn't stdin
  test edi, edi
  jz .run
  push 6                        ; SYS_close
  pop eax
  mov ebx, edi
  int 0x80

.run:
  ; Reset the memfd internal offset pointer back to 0 before executing
  push 19                       ; SYS_lseek
  pop eax
  mov ebx, [memfd]              ; target descriptor
  xor ecx, ecx                  ; offset = 0
  xor edx, edx                  ; whence = SEEK_SET (0)
  int 0x80

  ; Execute whatever is in the memfd. 
  ; Kernel's binary handler automatically tests for ELF magic or Shebang (#!)
  mov eax, 358                  ; SYS_execveat
  mov ebx, [memfd]              ; EBX = target memfd
  push 0                        ; empty path target string
  mov ecx, esp                  ; ECX = points to ""
  mov edx, [argv_ptr]           ; EDX = original unmodified parameters
  mov esi, ebp                  ; ESI = environment array
  mov edi, 0x1000               ; EDI = AT_EMPTY_PATH
  int 0x80                      ; Context switch to payload
  jmp exit_error

; ==============================================================================
; UTILITY SUBROUTINES
; ==============================================================================

fetch_byte:
  test ecx, ecx
  jnz .from_buf

  push edx
  push ebx
  mov eax, 3                    ; SYS_read
  mov ebx, edi
  mov ecx, buf
  mov edx, 512
  int 0x80
  pop ebx
  pop edx

  test eax, eax
  jle .eof

  mov ecx, eax                  
  mov esi, buf                  

.from_buf:
  lodsb                         
  dec ecx
  clc                           
  ret

.eof:
  stc                           
  ret

write_byte:
  push ecx
  push edx
  push ebx
  push eax                      
  
  mov ecx, esp                  
  mov edx, 1                   
  mov ebx, [memfd]              
  mov eax, 4                    ; SYS_write
  int 0x80
  
  pop eax                       
  pop ebx
  pop edx
  pop ecx
  ret

; ==============================================================================
; EXIT HANDLER
; ==============================================================================
exit_error:
  push 1                        ; SYS_exit
  pop eax
  xor ebx, ebx
  inc ebx                       ; exit code 1
  int 0x80

; ==============================================================================
; DATA STRUCTURES
; ==============================================================================
copy_vers:  db "(c) github/robang74 v0.81 Univ", 0
filename:   db "uzpexec", 0
eof_strng:  db "elf_eof", 0

; Aligned to 512 boundary
file_end:
times (511 - ($ - $$)) db 0
end_code: db 0

; ==============================================================================
; RUNTIME MEMORY ALLOCATION (BSS)
; ==============================================================================
bss_start equ $$ + 512

memfd:    equ bss_start + 0    
argv_ptr: equ bss_start + 4     
buf:      equ bss_start + 8    
bss_end:  equ buf + 512
