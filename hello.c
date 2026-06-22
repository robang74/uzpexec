#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    char *home, *world;

    printf("Hello %s%sWorld!\n",
           argv[1] ? argv[1] : "", argv[1] ? " " : "");

    home  = getenv("HOME");
    printf("  HOME:  %s\n", home  ?: "(none)");

    world = getenv("WORLD");
    printf("  WORLD: %s\n", world ?: "(none)");

    return 0;
}
