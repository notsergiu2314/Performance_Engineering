/*
 * nothp: run a command with transparent huge pages disabled (no root needed).
 *
 * HAICGU runs RHEL with 64 KB base pages and THP=always, i.e. 512 MB huge
 * pages. CloverLeaf's ~118 MB arrays are allocated back to back, so a few huge
 * pages cover them and each lands completely on the NUMA domain whose thread
 * touched it first. PR_SET_THP_DISABLE is inherited across fork/exec, so
 * `nothp <cmd>` (also as the program after mpirun) turns this off for that
 * process tree only.
 *
 * Build: gcc -O2 nothp.c -o nothp
 * Use:   ./nothp ./clover_base      mpirun ... ./nothp ./clover_base
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/prctl.h>
#include <unistd.h>

#ifndef PR_SET_THP_DISABLE
#define PR_SET_THP_DISABLE 41
#define PR_GET_THP_DISABLE 42
#endif

int main(int argc, char **argv)
{
  if (argc < 2) {
    fprintf(stderr, "usage: %s command [args...]\n", argv[0]);
    return 2;
  }
  if (prctl(PR_SET_THP_DISABLE, 1, 0, 0, 0) != 0) {
    perror("prctl(PR_SET_THP_DISABLE)");
    return 1;
  }
  if (getenv("NOTHP_VERBOSE"))
    fprintf(stderr, "[nothp] THP disabled for this process tree: %d\n",
            prctl(PR_GET_THP_DISABLE, 0, 0, 0, 0));
  execvp(argv[1], argv + 1);
  perror("execvp");
  return 127;
}
