# Lab 7 ex2: MPI ring benchmark.  make  ->  ./mpi_ring   (needs mpicc: module load GCC OpenMPI)
CC     ?= mpicc
CFLAGS ?= -O2 -std=c11 -Wall -Wextra

mpi_ring: mpi_ring.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f mpi_ring

.PHONY: clean
