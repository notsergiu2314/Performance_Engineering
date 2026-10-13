# Lab 6, exercise 1: STREAM kernels with OpenMP.
#   make            build stream_omp (and nothp on Linux)
# aarch64 (HAICGU Kunpeng 920) wants -mcpu=native, x86 -march=native.
ARCH := $(shell uname -m | grep -q aarch64 && echo -mcpu=native || echo -march=native)
CC    = gcc
CFLAGS = -O3 -fopenmp $(ARCH) -Wall -Wextra

.PHONY: all clean
all: stream_omp nothp

stream_omp: stream_omp.c
	$(CC) $(CFLAGS) $< -o $@

nothp: nothp.c
	$(CC) -O2 $< -o $@

clean:
	rm -f stream_omp nothp
