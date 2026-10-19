# Lab 7 ex2: MPI ring benchmark.  make  ->  ./mpi_ring   (needs mpicc: module load GCC OpenMPI)
# not CC: make predefines CC=cc, so `CC ?= mpicc` would never take effect
MPICC  ?= mpicc
CFLAGS ?= -O2 -std=c11 -Wall -Wextra

mpi_ring: mpi_ring.c
	$(MPICC) $(CFLAGS) $< -o $@

clean:
	rm -f mpi_ring

.PHONY: clean
