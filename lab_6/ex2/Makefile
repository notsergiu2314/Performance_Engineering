CC  = gcc
CFLAGS   = -O3 -march=native -fopenmp

TARGETS = parallel_matvec

.PHONY: all clean

all: ${TARGETS}

parallel_matvec: openmp_ex2.c
	${CC} ${CFLAGS} $< -o $@

clean:
	rm -f ${TARGETS}
