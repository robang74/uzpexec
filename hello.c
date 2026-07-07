#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    char *home, *world;
    int nsec = 0;

    printf("\nHello %s%sWorld!\n",
           argv[1] ? argv[1] : "", argv[1] ? " " : "");

    home  = getenv("HOME");
    printf("   HOME: '%s'\n", home    ?: "(none)");

    world = getenv("WORLD");
    printf("  WORLD: '%s'\n", world   ?: "(none)");

    printf("  ARGV0: '%s'\n", argv[0] ?: "(none)");

    nsec = atoi(argv[argc-1]);
    if(nsec > 0)  {
        printf("Sleeping %ds ...\n", nsec);
        sleep (nsec);
    }
//  printf("argc: %d, %d, %s\n", argc, nsec, argv[argc-1]);
    return 0;
}
