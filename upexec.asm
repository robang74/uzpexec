; ==============================================================================
; (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
; ==============================================================================
; Rationale upexec (micro pipe exec)
;
; Utility for executing an ELF binary directly from stdin pipe:
; - it runs binary via SSH/wget
; - it runs compressed binary
; without write it on the remote/local systems (memfd_create).
;
; Compile and test (simple example)
;
; printf '#include<stdio.h>\nint main() { puts("Hello World!"); return 0; }\n' |
; cc -Os -s -xc - -o hi && du -b hi && gzip -f hi && du -b hi.gz
; # 14472 hi
; #  1707 hi.gz
; nasm -O2 -f bin upexec.asm -o upexec && du -b upexec && chmod a+x upexec
; #   244 upexec
; zcat hi.gz | ./upexec; echo $?
; # Hello World!
; # 0
; ==============================================================================
BITS 32

org 0x08048000

; ==============================================================================
; ELF32 HEADER (Handwritten to completely eliminate overhead)
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
  ; 1. mfd = memfd_create("u", MFD_CLOEXEC)
  ; Note: On 32-bit, the syscall number for memfd_create is 356
  mov eax, 356                ; SYS_memfd_create
  mov ebx, filename           ; Pointer to the anonymous filename
  mov ecx, 1                  ; MFD_CLOEXEC to !leaking FD to child processes
  int 0x80                    ; Linux kernel call (int 0x80 is the 32-bit)
  test eax, eax
  js exit_error               ; < 0: there's an error (e.g., kernel too old)
  mov edi, eax                ; Save the file descriptor into EDI for later

read_block_setup:
  ; Prepare registers to accumulate an atomic 512-byte block
  mov ecx, buf                ; Current pointer inside the buffer
  mov edx, 512                ; Bytes remaining to be read for this block

read_loop:
  ; 2. read(0, buf, 512) reads from STDIN in 512-byte blocks (dd style)
  mov eax, 3                  ; SYS_read
;   mov ebx, 0                  ; STDIN
  xor ebx, ebx                ; STDIN is 0 = a^a (but shorter code)
  int 0x80

  test eax, eax
  jz flush_and_execute        ; EAX == 0 is EOF: write last chunk and execute
  cmp eax, -4                 ; EAX == -EINTR (interrupted system call)
  je read_loop                ; Ignore EINTR and retry the read
  js exit_error               ; Any other negative error: exit

  ; If we are here, we have read X bytes (in EAX)
  sub edx, eax                ; Subtract bytes read from the missing (512-N)
  add ecx, eax                ; Move buffer pointer forward for the next read
  test edx, edx
  jnz read_loop               ; edx > 0: partial 512-byte read, keep reading

  ; --- THE 512-BYTE BLOCK IS NOW COMPLETE ---
  ; Write the entire block into the memfd
  mov eax, 4                  ; SYS_write
  mov ebx, edi                ; Our memfd
  mov ecx, buf                ; Start from the beginning of the buffer
  mov edx, 512                ; Write exactly 512 bytes
  int 0x80
  js exit_error

  jmp read_block_setup        ; Reset and proceed to the next 512-byte block

flush_and_execute:
  ; If the pipe ends but we had accumulated a partial block in RAM,
  ; we must flush the remaining bytes before launching the executable.
  mov eax, 512
  sub eax, edx                ; Calculate partial block size
  jz execute_now              ; 0: read completed, proceed to execution

  mov edx, eax                ; EDX = remaining bytes
  mov eax, 4                  ; SYS_write
  mov ebx, edi                ; memfd
  mov ecx, buf                ; Beginning of the buffer
  int 0x80
  js exit_error

execute_now:
  ; 4. Minimum security setup of the stack for argv
  ; Avoids kernel ENOEXEC rejection by injecting a fake argv[0]
  push 0                      ; NULL terminator for envp
  push 0                      ; NULL terminator for argv
  mov ecx, esp                ; ECX points to the structure [filename, NULL]
  mov eax, filename
  push eax                    ; argv[0] = filename

  ; Now that the stack has changed, save the NEW stack pointer into EDX
  mov edx, esp                ; EDX points to the structure [filename, NULL]
  xor esi, esi                ; envp = NULL

  ; 5. execveat(mfd, "", argv, envp, AT_EMPTY_PATH)
  mov eax, 358                ; SYS_execveat
  mov ebx, edi                ; Our memfd
  
  ; To order registers for the execveat(ebx, ecx, edx, esi, edi) syscall:
  ; EBX = mfd  (edi)
  ; ECX = ""   (preserved from the previous mov ecx, esp)
  ; EDX = argv (moved to edx instead of ecx!)
  ; ESI = envp (esi)
  ; EDI = AT_EMPTY_PATH (0x1000)
  mov edi, 0x1000             ; AT_EMPTY_PATH
  int 0x80

exit_error:
  mov eax, 1                  ; SYS_exit
  mov ebx, 1                  ; Exit code 1
  int 0x80

; ==============================================================================
; COMPACT DATA SECTION (Appended to code)
; ==============================================================================
filename: db "upexec", 0      ; this is the /proc/self/cmdline executable name
file_end:                     ; Physical end of the binary file!

; ==============================================================================
; UNINITIALIZED BSS SECTION (Exists ONLY in RAM, zero bytes on disk)
; ==============================================================================
absolute_address equ $
buf equ absolute_address + 4  ; It starts immediately after the EOF
bss_end equ buf + 512         ; Reserve 512 bytes for the buffer

