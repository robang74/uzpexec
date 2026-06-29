// sigsegv.c — compila: cc -s -Os sigsegv.c -o sigsegv
#include <unistd.h>
int main(int argc, char *argv[]) {
#pragma message "!!!"
#pragma message "Following two warnings are expected here"
#pragma message "!!!"
    execve((char *)NULL, (char *[]){NULL}, (char *[]){NULL});
    return 127;
}
