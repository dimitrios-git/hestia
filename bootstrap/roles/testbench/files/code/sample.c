#include <stdio.h>
#include <stdlib.h>

#define MAX 10 /* object-like macro */

// line comment; TODO: types, builtins, operators
typedef struct {
    int id;
    char *name;
} User;

int main(int argc, char **argv) {
    unsigned long total = 0UL;
    for (int i = 0; i < MAX && argc > 1; i++) {
        total += (unsigned)i * 2;
        printf("i=%d\n", i); // builtin call
    }
    return total == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
