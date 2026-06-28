// sigsegv.c — compila: cc -s -Os sigsegv.c -o sigsegv
#include <unistd.h>
int main(int argc, char *argv[]) {
    execve(argv[1], (char *[]){NULL}, (char *[]){NULL});
    return 127;
}
