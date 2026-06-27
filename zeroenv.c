// zeroenv.c — compila: cc -s -Os zeroenv.c -o zeroenv
#include <unistd.h>
int main(int argc, char *argv[]) {
    char *new_argv[] = {argv[1], NULL};
    execve(argv[1], new_argv, (char *[]){NULL});
    return 15;
}
