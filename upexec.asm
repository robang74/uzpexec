; ==============================================================================
; (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
;     Coded with the support of Gemini and then Kimi for the size reduction
; ==============================================================================
;
; Usage: zcat elf.gz | upexec [args]
;
; Rationale upexec (micro pipe exec)
;
; Utility for executing an ELF binary directly from stdin pipe:
; - it runs binary via SSH/wget
; - it runs compressed binary
; without write it on the remote/local systems (memfd_create).
;
; Compile and test (simple example)
;
; cc -Os -s hello.c -o hi && du -b hi && gzip -f hi && du -b hi.gz
; # 14472 hi
; #  1868 hi.gz
; nasm -O2 -f bin upexec.asm -o upexec && du -b upexec && chmod a+x upexec
; #   242 upexec
; export WORLD=beautiful; zcat hi.gz | ./upexec $WORLD; echo $?
; # Hello beautiful World!
; #   HOME:  /home/roberto
; #   WORLD: beautiful
; # 0
; ==============================================================================

BITS 32
org 0x08048000

; ==============================================================================
; ELF32 HEADER (Micro-Loader a 32-bit, Teeny ELF)
; ==============================================================================
elf_header:
  db 0x7F, 'ELF', 1, 1, 1, 0  ; e_ident (Magic, Class 32bit, Data LSB, Version)
  times 8 db 0                ; Padding for e_ident
  dw 2                        ; e_type (Executable)
  dw 3                        ; e_machine (Intel 80386)
  dd 1                        ; e_version
  dd code_start               ; e_entry (The starting point of our code)
  dd phdr - elf_header        ; e_phoff (Offset of the Program Header Table)
  dd 0                        ; e_shoff (No Section Header Table, saving bytes)
  dd 0                        ; e_flags
  dw 52                       ; e_ehsize (Size of this header)
  dw 32                       ; e_phentsize (Size of a Program Header entry)
  dw 1                        ; e_phnum (Only one segment needed)
  ; Many Linux kernel ELF parsers completely ignore these
  ; 6 bytes when section offset e_shoff = 0, as in this case
  dw 0, 0, 0                  ; Section info (zeroed out)

phdr:
  dd 1                        ; p_type (PT_LOAD - Segment to load)
  dd 0                        ; p_offset
  dd 0x08048000               ; p_vaddr (Virtual address in memory)
  dd 0x08048000               ; p_paddr
  dd file_end - elf_header    ; p_filesz (Size of the code within the file)
  dd bss_end - elf_header     ; p_memsz (Size of the code within memory)
  dd 7                        ; p_flags (R+W+X - Read, Write, and Execute)
  dd 0x1000                   ; p_align (Standard page alignment)

; ==============================================================================
; upexec CODE (Execution starts here)
; ==============================================================================
code_start:
  ; Save original argv and calculate envp from the initial stack layout
  ; Stack: [argc] [argv[0]] ... [argv[N]] [NULL] [envp...]
  pop eax                 ; argc (was [esp])
  mov esi, esp            ; ESI = argv
  lea ebp, [esi+eax*4+4]  ; EBP = envp (callee-saved!)

  ; mfd = memfd_create("upexec", MFD_CLOEXEC)
  mov eax, 356                ; SYS_memfd_create
  mov ebx, filename           ; Pointer to the anonymous filename "upexec"
  push 1                      ; MFD_CLOEXEC
  pop ecx
  int 0x80                    ; Linux kernel call

  test eax, eax
  js exit_error               ; < 0: error
  mov edi, eax                ; Save EDI = memfd

read_block_setup:
  ; Prepare registers to accumulate an atomic 512-byte block
  mov ecx, buf                ; Current pointer inside the buffer
  mov edx, 512                ; Bytes remaining to be read for this block

read_loop:
  ; read(0, buf, 512) reads from STDIN in 512-byte blocks (dd style)
  ; SPEED: mov eax,3 (1 ALU µop, 1 cycle) vs push/pop (2 µops, 4-5 cycles)
  ; push 3                    ; 2 bytes: SYS_read
  ; pop eax                   ; 1 byte
  mov eax, 3                  ; 5 bytes: SYS_read
  xor ebx, ebx                ; STDIN is 0 = a^a (but shorter code)
  int 0x80

  test eax, eax
  jz flush                    ; EAX == 0 is EOF: write last chunk and execute
  cmp eax, -4                 ; EAX == -EINTR (interrupted system call)
  je read_loop                ; Ignore EINTR and retry the read
  js exit_error               ; Any other negative error: exit

  ; If we are here, we have read X bytes (in EAX)
  sub edx, eax                ; Subtract bytes read from the missing (512-N)
  add ecx, eax                ; Move buffer pointer forward for the next read
  test edx, edx
  jnz read_loop               ; edx > 0: partial 512-byte read, keep reading

  ; Write the entire block into the memfd
  ; SPEED: mov eax,4 (1 ALU µop, 1 cycle) vs push/pop (2 µops, 4-5 cycles)
  ; push 4                    ; 2 bytes: SYS_write
  ; pop eax                   ; 1 byte
  mov eax, 4                  ; 5 bytes: SYS_write
  mov ebx, edi                ; Our memfd
  mov ecx, buf                ; Start from the beginning of the buffer
  mov edx, 512                ; Write exactly 512 bytes
  int 0x80
  js exit_error

  jmp read_block_setup        ; Reset and proceed to the next 512-byte block

flush:
  ; If the pipe ends but we had accumulated a partial block in RAM,
  ; we must flush the remaining bytes before launching the executable.
  mov eax, 512
  sub eax, edx                ; Calculate partial block size
  jz execute                  ; 0: read completed, proceed to execution

  mov edx, eax                ; EDX = remaining bytes
  push 4                      ; SYS_write
  pop eax
  mov ebx, edi                ; memfd
  mov ecx, buf                ; Beginning of the buffer
  int 0x80
  js exit_error

execute:
  ; Fix argv[0] to point to our custom name "upexec"
  mov eax, filename           ; Load address of "upexec"
  mov [esi], eax              ; Overwrite original argv[0]

  ; execveat(memfd, "", argv, envp, AT_EMPTY_PATH)
  mov eax, 358                ; SYS_execveat syscall number
  mov ebx, edi                ; EBX = anonymous memfd descriptor
  push 0                      ; set the empty path "" in stack
  mov ecx, esp                ; ECX = pointer to empty path ""
  mov edx, esi                ; ESI = pointer to original envp[]
  mov esi, ebp                ;       envp from EBP!
  mov edi, 0x1000             ; EDI = AT_EMPTY_PATH flag
  int 0x80                    ; Invoke Linux kernel to replace process

exit_error:
  push 1                      ; SYS_exit
  pop eax
  push 1                      ; Exit code 1
  pop ebx
  int 0x80

; ==============================================================================
; COMPACT DATA SECTION (Appended to code)
; ==============================================================================
filename: db "upexec", 0      ; this is the /proc/self/cmdline executable name
file_end:                     ; Physical end of the binary file!

; ==============================================================================
; UNINITIALIZED BSS SECTION (Exists ONLY in RAM)
; ==============================================================================
absolute_address equ $
buf equ file_end + 4          ; It starts immediately after the EOF
bss_end equ buf + 512         ; Reserve 512 bytes for the buffer

