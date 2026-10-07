CC  = gcc
CXX = g++
CFLAGS   = -O2 -Wall
CXXFLAGS = -O2 -Wall

TARGETS = blocked_matvec benchmark_malloc

.PHONY: all clean

all: ${TARGETS}

blocked_matvec: c-blocked_matvec_mult.c
	${CC} ${CFLAGS} $< -o $@

benchmark_malloc: benchmark_malloc.cpp
	${CXX} ${CXXFLAGS} $< -o $@

clean:
	rm -f ${TARGETS}
