#include <stdio.h>

int main(int argc, char *argv[]) {
	printf( "Hello %s%sWorld!\n",
	  argv[1]?:"", argv[1]?" ":"" );
	return 0;
}
