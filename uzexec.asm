; ==============================================================================
; (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
;     Coded with the support of Kimi and then Gemini for the size reduction
; ==============================================================================
;
; USAGE:
; - a) { cat uzexec; gzip -c $elfbin; } > $self-extracting-executable
; - b) cp uzexec $zelfbin; gzip -c $elfbin >> $zelfbin (the same ^^^)
; - c) wget $url/$elf.gz -O- | uzexec [args]
;
; ==============================================================================
;
; Fix for the 2-pipe architecture for zcat:
; - 1. Reads itself (from argv[0] or stdin)
; - 2. Discards the first 512 bytes (skips the header/loader)
; - 3. Sends the remainder to zcat via pipe
; - 4. Reads the unpacked output from zcat and loads it into an anonymous memfd
; - 5. Executes the code from the memfd
;
; Single Pipe Optimization with Direct Writing, Architecture:
; - Only one pipe (input), fork, child writes directly to memfd via dup2.
;
; Optimization: Ultra-High Efficiency version (Zero Pipes)
; Transparently supports both files (argv[0]) and stdin without allocating pipes.
;
; Parent:
; - open(argv[0]) → fd 3 (or stdin = 0)
; - memfd_create() → fd 4
; - skip 512 bytes from fd 3 (read loop)
; - fork()
;
; Child:
; - dup2(fd 3, 0)    ; stdin = input (offset already advanced by 512 bytes!)
; - dup2(fd 4, 1)    ; stdout = memfd
; - execve("zcat", ["zcat", "-"], NULL)
;
; Parent:
; - waitpid(-1, ...)
; - execveat(fd 4, "", argv, envp, AT_EMPTY_PATH)
;
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
  pop eax                       ; argc
  mov esi, esp                  ; argv
  lea ebp, [esi+eax*4+4]        ; envp

  ; 1. Checking argv[0] to open input (itself or stdin)
  mov ebx, [esi]
  test ebx, ebx
  jz .stdin
  cmp byte [ebx], 0
  jz .stdin

  ; ------------ Trova la fine del percorso (basename) in argv[0] --------------
  mov edx, ebx                  ; edx = inizio di argv[0]
.find_end:
  inc edx
  cmp byte [edx], 0
  jnz .find_end
                                ; Fine della stringa, andiamo al confronto
.check_basename:
  ; Ora torniamo indietro per trovare l'ultimo '/' o l'inizio di argv[0]
  ; edx punta al terminatore '\0'
.backtrack:
  cmp edx, ebx                  ; Siamo tornati all'inizio di argv[0]?
  je .do_strcmp                 ; Sì, confronta da qui
  dec edx
  cmp byte [edx], '/'           ; Abbiamo trovato un separatore di percorso?
  jne .backtrack
  inc edx                       ; Salta il '/' per puntare al nome del file

.do_strcmp:
  ; edx ora punta esattamente all'inizio del "basename" (es. "uzexec\0")
  ; Lo confrontiamo carattere per carattere con `filename`
  mov ecx, filename
.strcmp_loop:
  mov al, [edx]
  mov ah, [ecx]
  cmp al, ah
  jne .not_uzexec               ; Se differisce, apri file
  test al, al                   ; Siamo arrivati allo '\0'?
  jz .stdin                     ; Corrispondenza esatta!
  inc edx
  inc ecx
  jmp .strcmp_loop
  ; ----------------------------------------------------------------------------

.not_uzexec:
  ; Se non è "uzexec", proviamo ad aprire il file (modalità embedded payload)
  xor ecx, ecx                  ; O_RDONLY
  push 5                        ; SYS_open
  pop eax
  int 0x80
  test eax, eax
  js exit_error
  mov edi, eax                  ; EDI = input fd (file aperto)

  ; 3. Salta il blocco iniziale di 512 byte (solo per file con payload)
  mov ecx, buf
  mov edx, 512
.skip_loop:
  push 3                        ; SYS_read
  pop eax
  mov ebx, edi                  ; input fd
  int 0x80
  test eax, eax
  js exit_error
  jz exit_error                 ; Premature EOF if the file is smaller than 512 bytes
  sub edx, eax
  jnz .skip_loop
  jmp .memfd

.stdin:
  xor edi, edi                  ; EDI = stdin (0)

.memfd:
  ; Crea direttamente il memfd senza passare dal ciclo skip_loop
  mov eax, 356                  ; SYS_memfd_create
  mov ebx, filename             ; fd owner's name
  push 1                        ; MFD_CLOEXEC
  pop ecx
  int 0x80
  test eax, eax
  js exit_error
  mov [memfd_saved], eax
  ; Flusso lineare: cade naturalmente dentro .fork_now senza salti cross-scope

.fork_now:
  ; 4. Fork (Senza allocare pipe!)
  push 2                        ; SYS_fork
  pop eax
  int 0x80
  test eax, eax
  jz child                      ; If EAX == 0, go to child process

  ; ============================================================================
  ; PARENT PROCESS
  ; ============================================================================
  ; The parent only needs to wait for the child (zcat) to finish decompressing
; mov ebx, -1                   ; RAF: -2 bytes
  xor ebx, ebx
  dec ebx
  xor ecx, ecx
  xor edx, edx
  push 7                        ; SYS_waitpid
  pop eax
  int 0x80

  ; Closes the initial input if it was an open file (no longer needed in the parent)
  test edi, edi
  jz execute
  push 6                        ; SYS_close
  pop eax
  mov ebx, edi                  ; Closes the origin input fd
  int 0x80

execute:
  ; Configures argv[0] and executes from the memfd
  ; mov eax, filename
  ; mov [esi], eax              ; ESI contains the pointer to the original argv

  ; Execution from the memfd, which now contains the entire unpacked binary
  ; Clean restoration of the stack before execveat to avoid EFAULT
  mov eax, 358                  ; SYS_execveat
  mov ebx, [memfd_saved]        ; EBX = validated memfd
  push 0                        ; push empty string "" to the stack
  mov ecx, esp                  ; ECX = points to ""
  mov edx, esi                  ; EDX = intact original argv
  mov esi, ebp                  ; ESI = envp (extracted from EBP)
  mov edi, 0x1000               ; EDI = AT_EMPTY_PATH flag
  int 0x80
  jmp exit_error

  ; ============================================================================
  ; CHILD PROCESS (Executes zcat by connecting existing descriptors)
  ; ============================================================================
child:
  ; dup2: connects the input fd (already positioned at +512 bytes) to the STDIN (0) of zcat
  ; Note: if EDI was already 0 (original stdin), dup2(0, 0) is a safe kernel no-op
  push 63                       ; SYS_dup2
  pop eax
  mov ebx, edi
  xor ecx, ecx                  ; 0 = stdin
  int 0x80

  ; dup2: connects the MEMFD directly to the STDOUT (1) of zcat
  push 63                       ; SYS_dup2
  pop eax
  mov ebx, [memfd_saved]
  push 1
  pop ecx                       ; 1 = stdout
  int 0x80

  ; Clean execution of simple zcat (zcat -)
  push 11                       ; SYS_execve
  pop eax
  mov ebx, zcat_path
  push 0
  push dash_arg
; push force_arg
  push zcat_path
  mov ecx, esp
  xor edx, edx
  int 0x80

exit_error:
  push 1                        ; SYS_exit
  pop eax
  xor ebx, ebx
  inc ebx                       ; Exit code 1
  int 0x80

; ==============================================================================
; DATA SECTION
; ==============================================================================
filename:   db "uzexec", 0
zcat_path:  db "/bin/zcat", 0
; RAF: this can be a security problem, a corrupted gzip archive should fail!
; force_arg:  db "-f", 0        ; "zcat -f" is cat when input isn't gzip
dash_arg:   db "-", 0

; ==============================================================================
; PADDING: Aligned exactly to 512 bytes (as per skip request)
; ==============================================================================
file_end:
times (512 - ($ - $$)) db 0     ; Padding to 512 bytes set as limit

; ==============================================================================
; BSS SECTION (RAM only, aligned to 512 bytes)
; ==============================================================================
bss_start equ $$ + 512

memfd_saved: equ bss_start + 0  ; Only variable needed besides the buffer
buf:         equ memfd_saved + 4
bss_end:     equ buf + 512

