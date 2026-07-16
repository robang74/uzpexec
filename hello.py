#!/usr/bin/python3

import os
import sys

def main():
    # 1. Gestione di ${1:-}${1:+ }World!
    # Se c'è almeno un argomento (oltre al nome dello script), prende il primo
    arg1 = sys.argv[1] if len(sys.argv) > 1 else ""
    spacing = " " if arg1 else ""
    print(f"Hello {arg1}{spacing}World!")

    # 2. Equivalente di 'command ls -q /proc/$$/fd/'
    # Recupera i file descriptor aperti dal processo Python corrente ($$)
    pid = os.getpid()
    fd_path = f"/proc/{pid}/fd"
    try:
        fds = os.listdir(fd_path)
        # ls -q sostituisce i caratteri non stampabili con '?', 
        # in Python uniamo semplicemente i nomi dei FD separati da spazio
        fds_str = " ".join(fds)
    except FileNotFoundError:
        fds_str = ""
    print(f"lsfd: {fds_str}")

    # 3. Equivalente di 'args: $@'
    # sys.argv[1:] prende tutti gli argomenti passati escludendo il nome del file
    args_str = " ".join(sys.argv[1:])
    print(f"args: '{args_str}'")

    # 4. Variabili d'ambiente $HOME e $WORLD (con fallback a stringa vuota se non impostate)
    home_env = os.environ.get("HOME", "")
    world_env = os.environ.get("WORLD", "")
    print(f"HOME: '{home_env}'")
    print(f"WORLD: '{world_env}'")

    # 5. exit $?
    # In Python, l'esecuzione dello script terminata con successo restituisce 0
    sys.exit(0)

if __name__ == "__main__":
    main()
