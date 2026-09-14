#include <stdio.h>

long x;

void func() {
    x += 1;
}

int main() {
    x = 1;
    x += 3;
    func();
    printf("%ld\n", x);
    return 0;
}