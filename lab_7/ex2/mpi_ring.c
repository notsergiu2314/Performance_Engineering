/*
 * Lab 7 ex2: MPI point-to-point ring benchmark.
 *
 * Rank i sends a message of `size` bytes to rank (i+1) mod N and receives one of the same size
 * from rank (i-1) mod N. N is whatever mpiexec starts. Send and receive are posted together with
 * MPI_Sendrecv, so the ring cannot deadlock (also not for N = 2, where both ranks send first).
 *
 * Usage:  mpiexec -n N ./mpi_ring [M] [trials] [size ...]
 *   M       exchanges per trial; 0 (default) = choose M per size so that one trial lasts ~0.2 s
 *   trials  repetitions of the whole measurement per size (default 10)
 *   size    message sizes in bytes (default 128 256 512 1024 2048 4096)
 *
 * Output (stdout, CSV; lines starting with '#' are comments):
 *   size_bytes,M,trial,nranks,time_s,time_per_exchange_us,bw_MBps
 * time_s is the slowest rank's wall time (MPI_Wtime) for M exchanges. bw_MBps is the payload one
 * rank sends per second, size*M/time_s (1 MB = 1e6 B); every rank also receives that much.
 */
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_SIZES 64
#define TARGET_S 0.2
#define CALIB_ITERS 200
#define WARMUP_ITERS 1000
#define M_MIN 1000L
#define M_MAX 2000000L

static int rank, nranks, right, left;
static unsigned char *sbuf, *rbuf;

static void exchange(int size, long iters)
{
    for (long k = 0; k < iters; k++)
        MPI_Sendrecv(sbuf, size, MPI_BYTE, right, 0,
                     rbuf, size, MPI_BYTE, left, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
}

/* wall time of `iters` exchanges, slowest rank (valid on every rank) */
static double timed(int size, long iters)
{
    double dt, mx;
    MPI_Barrier(MPI_COMM_WORLD);
    dt = MPI_Wtime();
    exchange(size, iters);
    dt = MPI_Wtime() - dt;
    MPI_Allreduce(&dt, &mx, 1, MPI_DOUBLE, MPI_MAX, MPI_COMM_WORLD);
    return mx;
}

int main(int argc, char **argv)
{
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &nranks);
    right = (rank + 1) % nranks;
    left = (rank - 1 + nranks) % nranks;

    long M_arg = argc > 1 ? atol(argv[1]) : 0;
    int trials = argc > 2 ? atoi(argv[2]) : 10;
    int sizes[MAX_SIZES], nsizes = 0;
    for (int a = 3; a < argc && nsizes < MAX_SIZES; a++)
        sizes[nsizes++] = atoi(argv[a]);
    if (nsizes == 0) {
        static const int def[] = {128, 256, 512, 1024, 2048, 4096};
        nsizes = (int)(sizeof def / sizeof def[0]);
        memcpy(sizes, def, sizeof def);
    }
    int maxsize = 0;
    for (int s = 0; s < nsizes; s++)
        if (sizes[s] > maxsize) maxsize = sizes[s];
    if (maxsize <= 0 || trials <= 0 || M_arg < 0) {
        if (rank == 0) fprintf(stderr, "usage: %s [M>=0] [trials>0] [size>0 ...]\n", argv[0]);
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    sbuf = malloc(maxsize);
    rbuf = malloc(maxsize);
    if (!sbuf || !rbuf) MPI_Abort(MPI_COMM_WORLD, 2);
    memset(sbuf, rank + 1, maxsize); /* touch every page before timing */
    memset(rbuf, 0, maxsize);

    /* where did the ranks end up? (rank 0 prints it so that the results file says) */
    char name[MPI_MAX_PROCESSOR_NAME] = {0};
    int len;
    MPI_Get_processor_name(name, &len);
    char *all = rank == 0 ? malloc((size_t)nranks * MPI_MAX_PROCESSOR_NAME) : NULL;
    MPI_Gather(name, MPI_MAX_PROCESSOR_NAME, MPI_CHAR, all, MPI_MAX_PROCESSOR_NAME, MPI_CHAR,
               0, MPI_COMM_WORLD);

    /* correctness: the message of rank i must arrive at rank i+1 intact */
    exchange(maxsize, 1);
    int bad = 0;
    for (int b = 0; b < maxsize; b++)
        if (rbuf[b] != (unsigned char)(left + 1)) { bad = 1; break; }
    int any_bad;
    MPI_Allreduce(&bad, &any_bad, 1, MPI_INT, MPI_MAX, MPI_COMM_WORLD);

    /* iterations per trial, one per size */
    long M[MAX_SIZES];
    for (int s = 0; s < nsizes; s++) {
        long m = M_arg;
        if (m == 0) {
            exchange(sizes[s], WARMUP_ITERS);
            double t = timed(sizes[s], CALIB_ITERS);
            m = (long)(TARGET_S / (t / CALIB_ITERS));
            if (m < M_MIN) m = M_MIN;
            if (m > M_MAX) m = M_MAX;
        }
        MPI_Bcast(&m, 1, MPI_LONG, 0, MPI_COMM_WORLD); /* all ranks must agree */
        M[s] = m;
    }

    if (rank == 0) {
        printf("# ring benchmark, MPI_Sendrecv, N=%d ranks, payload check %s\n", nranks,
               any_bad ? "FAILED" : "ok");
        for (int r = 0; r < nranks; r++)
            printf("# rank %d on %s\n", r, all + (size_t)r * MPI_MAX_PROCESSOR_NAME);
        printf("size_bytes,M,trial,nranks,time_s,time_per_exchange_us,bw_MBps\n");
    }

    /* trial-outer, size-inner: a disturbance hits one trial of every size, not all of one size */
    for (int t = 0; t < trials; t++)
        for (int s = 0; s < nsizes; s++) {
            exchange(sizes[s], WARMUP_ITERS);
            double T = timed(sizes[s], M[s]);
            if (rank == 0)
                printf("%d,%ld,%d,%d,%.9f,%.4f,%.3f\n", sizes[s], M[s], t, nranks, T,
                       T / M[s] * 1e6, (double)sizes[s] * M[s] / T / 1e6);
        }

    free(sbuf);
    free(rbuf);
    free(all);
    MPI_Finalize();
    return any_bad ? 1 : 0;
}
