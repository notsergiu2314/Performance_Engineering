#include <stdio.h>

extern long x;

void func ();

int main() {
    x = 1;
    func();
    x += 3;

    printf("x = %ld\n", x);
}