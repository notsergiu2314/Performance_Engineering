/**
 *  @brief Per-kernel hardware counter instrumentation (PAPI).
 *  @details See papi_prof.h. Each OpenMP thread lazily creates its own
 *  PAPI event set the first time it enters an instrumented kernel and keeps
 *  the counters running; a region only reads them at entry and exit, so the
 *  cost per kernel call is two PAPI_read calls per thread. The barrier at the
 *  end of the last "omp for" is included in the measurement, i.e. a thread
 *  that finishes early accumulates wait cycles (visible as load imbalance).
 *  Results are written at process exit.
 */

#include "papi_prof.h"

#ifdef USE_PAPI

#include <papi.h>
#include <omp.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define PROF_MAX_THREADS 512
#define PROF_MAX_EVENTS  16

typedef struct {
  int       state;                     /* 0 = new, 1 = counting, -1 = failed */
  int       eventset;
  double    t_start;
  long long c_start[PROF_MAX_EVENTS];
  long long counts[PROF_NREGIONS][PROF_MAX_EVENTS];
  double    time[PROF_NREGIONS];
  long      calls[PROF_NREGIONS];
} thread_state;

static const char *region_names[PROF_NREGIONS] = { PROF_REGION_NAMES };

static pthread_once_t init_once = PTHREAD_ONCE_INIT;
static int            enabled;
static int            nevents;
static int            event_codes[PROF_MAX_EVENTS];
static char           event_names[PROF_MAX_EVENTS][PAPI_MAX_STR_LEN];
static thread_state  *states;
static int            nthreads_seen;
static __thread thread_state *my_state;

static unsigned long prof_thread_id(void)
{
  return (unsigned long) pthread_self();
}

static void prof_dump(void)
{
  const char *dir = getenv("PROF_DIR");
  char path[4096];
  FILE *f;
  int t, r, e;

  if (!enabled) return;
  snprintf(path, sizeof(path), "%s/papi_prof_%d.csv", dir ? dir : ".", (int) getpid());
  f = fopen(path, "w");
  if (!f) { perror("[papi_prof] fopen"); return; }

  fprintf(f, "region,thread,calls,time_s");
  for (e = 0; e < nevents; e++) fprintf(f, ",%s", event_names[e]);
  fprintf(f, "\n");
  for (t = 0; t < nthreads_seen && t < PROF_MAX_THREADS; t++) {
    for (r = 0; r < PROF_NREGIONS; r++) {
      if (states[t].calls[r] == 0) continue;
      fprintf(f, "%s,%d,%ld,%.9f", region_names[r], t, states[t].calls[r], states[t].time[r]);
      for (e = 0; e < nevents; e++) fprintf(f, ",%lld", states[t].counts[r][e]);
      fprintf(f, "\n");
    }
  }
  fclose(f);
  fprintf(stderr, "[papi_prof] wrote %s (%d threads, %d events)\n", path, nthreads_seen, nevents);
}

static void prof_init(void)
{
  const char *env = getenv("PROF_EVENTS");
  char *list, *tok, *save = NULL;
  int test = PAPI_NULL, code, ret;

  ret = PAPI_library_init(PAPI_VER_CURRENT);
  if (ret != PAPI_VER_CURRENT) {
    fprintf(stderr, "[papi_prof] PAPI_library_init failed (%d), profiling disabled\n", ret);
    return;
  }
  if ((ret = PAPI_thread_init(prof_thread_id)) != PAPI_OK) {
    fprintf(stderr, "[papi_prof] PAPI_thread_init: %s, profiling disabled\n", PAPI_strerror(ret));
    return;
  }

  /* Keep only events that can be counted together in one event set, so no
     multiplexing (and no extrapolation) happens behind our back. */
  list = strdup(env ? env : "PAPI_TOT_CYC,PAPI_TOT_INS");
  PAPI_create_eventset(&test);
  for (tok = strtok_r(list, ",", &save); tok; tok = strtok_r(NULL, ",", &save)) {
    if (*tok == '\0') continue;
    if (nevents == PROF_MAX_EVENTS) {
      fprintf(stderr, "[papi_prof] more than %d events, ignoring %s\n", PROF_MAX_EVENTS, tok);
      continue;
    }
    if ((ret = PAPI_event_name_to_code(tok, &code)) != PAPI_OK) {
      fprintf(stderr, "[papi_prof] unknown event %s (%s), skipped\n", tok, PAPI_strerror(ret));
      continue;
    }
    if ((ret = PAPI_add_event(test, code)) != PAPI_OK) {
      fprintf(stderr, "[papi_prof] cannot add %s (%s), skipped\n", tok, PAPI_strerror(ret));
      continue;
    }
    event_codes[nevents] = code;
    snprintf(event_names[nevents], PAPI_MAX_STR_LEN, "%s", tok);
    nevents++;
  }
  free(list);
  PAPI_cleanup_eventset(test);
  PAPI_destroy_eventset(&test);

  states = calloc(PROF_MAX_THREADS, sizeof(thread_state));
  if (!states) return;
  enabled = 1;
  atexit(prof_dump);
  fprintf(stderr, "[papi_prof] counting %d events\n", nevents);
}

static thread_state *prof_thread_state(void)
{
  thread_state *s = my_state;
  int slot, e;

  if (s) return s->state == 1 ? s : NULL;

  slot = __atomic_fetch_add(&nthreads_seen, 1, __ATOMIC_RELAXED);
  if (slot >= PROF_MAX_THREADS) return NULL;
  s = my_state = &states[slot];
  s->state = -1;
  s->eventset = PAPI_NULL;

  if (nevents > 0) {
    PAPI_register_thread();
    if (PAPI_create_eventset(&s->eventset) != PAPI_OK) return NULL;
    for (e = 0; e < nevents; e++)
      if (PAPI_add_event(s->eventset, event_codes[e]) != PAPI_OK) return NULL;
    if (PAPI_start(s->eventset) != PAPI_OK) return NULL;
  }
  s->state = 1;
  return s;
}

void prof_begin(int region)
{
  thread_state *s;

  (void) region;
  pthread_once(&init_once, prof_init);
  if (!enabled || !(s = prof_thread_state())) return;
  if (nevents > 0) PAPI_read(s->eventset, s->c_start);
  s->t_start = omp_get_wtime();
}

void prof_end(int region)
{
  thread_state *s;
  long long c[PROF_MAX_EVENTS];
  double t;
  int e;

  if (!enabled || !(s = prof_thread_state())) return;
  t = omp_get_wtime();
  if (nevents > 0) {
    PAPI_read(s->eventset, c);
    for (e = 0; e < nevents; e++) s->counts[region][e] += c[e] - s->c_start[e];
  }
  s->time[region] += t - s->t_start;
  s->calls[region]++;
}

#else

/* Keep the translation unit non-empty when PAPI is not enabled. */
typedef int papi_prof_unused;

#endif
