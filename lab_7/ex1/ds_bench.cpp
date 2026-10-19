// Lab 7, exercise 1: data-structure benchmark.
// Sorts a vector of records by one key field, as in the assignment code; the record
// layout and the sorting strategy are chosen at compile time (see Makefile):
//   -DLAYOUT=SMALL_BASE    char flg1; double x[7]; char flg2;        72 B, 16-B aligned
//   -DLAYOUT=SMALL_REORDER double x[7]; char flg1; char flg2;        64 B (field re-ordering)
//   -DLAYOUT=SMALL_ALIGN   as SMALL_REORDER, alignas(64)             64 B, one cache line per record
//   -DLAYOUT=BIG_BASE      int rank; double x[16384];                131080 B
//   -DLAYOUT=BIG_PAD       as BIG_BASE, alignas(64)                  131136 B (padding to a line multiple)
//   -DSPLIT=0  std::sort on the records (comparator reads the key, swaps move whole records)
//   -DSPLIT=1  structure splitting (combined with any layout; the Makefile's small_opt and big_opt
//              are SMALL_ALIGN+SPLIT and BIG_PAD+SPLIT): sort an array of (key, index) pairs, then apply the
//              permutation to the records once (cycle-leader, in place)
// Input: keys count..1 (reverse order), as in the assignment. Each repetition sorts in the
// opposite direction, so every repetition again starts from a reverse-ordered input
// without re-initialising anything. reps=0 only allocates and initialises; the driver
// subtracts that run from the others to get per-sort counter values.
//   ds_bench [count] [reps]      (count = number of records, default 16384)
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <vector>

#define SMALL_BASE 1
#define SMALL_REORDER 2
#define SMALL_ALIGN 3
#define BIG_BASE 4
#define BIG_PAD 5
#ifndef LAYOUT
#define LAYOUT SMALL_BASE
#endif
#ifndef SPLIT
#define SPLIT 0
#endif

const int n = 16384;  // payload length of Big, as in the assignment

struct SmallBase { char flg1; double x[7]; char flg2; };
struct SmallReorder { double x[7]; char flg1; char flg2; };
struct alignas(64) SmallAlign { double x[7]; char flg1; char flg2; };
struct BigBase { int rank; double x[n]; };
struct alignas(64) BigPad { int rank; double x[n]; };

#if LAYOUT == SMALL_BASE
using Rec = SmallBase; const char *layout_name = "small_base";
#elif LAYOUT == SMALL_REORDER
using Rec = SmallReorder; const char *layout_name = "small_reorder";
#elif LAYOUT == SMALL_ALIGN
using Rec = SmallAlign; const char *layout_name = "small_align";
#elif LAYOUT == BIG_BASE
using Rec = BigBase; const char *layout_name = "big_base";
#elif LAYOUT == BIG_PAD
using Rec = BigPad; const char *layout_name = "big_pad";
#else
#error "unknown LAYOUT"
#endif

#if SPLIT
#define SPLIT_SUFFIX "_split"
#else
#define SPLIT_SUFFIX ""
#endif

#if LAYOUT <= SMALL_ALIGN
using Key = double;
static inline Key &key(Rec &r) { return r.x[0]; }
static inline Key key(const Rec &r) { return r.x[0]; }
#else
using Key = int;
static inline Key &key(Rec &r) { return r.rank; }
static inline Key key(const Rec &r) { return r.rank; }
#endif

using clk = std::chrono::steady_clock;
static double secs(clk::time_point a, clk::time_point b) {
  return std::chrono::duration<double>(b - a).count();
}

// --- direct: std::sort on the records -------------------------------------------------
static void sort_direct(std::vector<Rec> &v, bool ascending, double &t_sort, double &t_perm) {
  auto t0 = clk::now();
  if (ascending)
    std::sort(v.begin(), v.end(), [](const Rec &a, const Rec &b) { return key(a) < key(b); });
  else
    std::sort(v.begin(), v.end(), [](const Rec &a, const Rec &b) { return key(a) > key(b); });
  t_sort += secs(t0, clk::now());
  t_perm += 0.0;
}

// --- split: sort (key, index) pairs, then permute the records once ----------------------
struct KeyIdx { Key k; uint32_t i; };

static void sort_split(std::vector<Rec> &v, bool ascending, double &t_sort, double &t_perm) {
  const uint32_t cnt = (uint32_t)v.size();
  static std::vector<KeyIdx> ki;        // the hot part: 16 B (Small) / 8 B (Big) per record
  static std::vector<char> done;
  ki.resize(cnt);
  done.assign(cnt, 0);
  auto t0 = clk::now();
  for (uint32_t i = 0; i < cnt; i++) ki[i] = {key(v[i]), i};
  if (ascending)
    std::sort(ki.begin(), ki.end(), [](const KeyIdx &a, const KeyIdx &b) { return a.k < b.k; });
  else
    std::sort(ki.begin(), ki.end(), [](const KeyIdx &a, const KeyIdx &b) { return a.k > b.k; });
  auto t1 = clk::now();
  // Position p must receive record ki[p].i. Follow each cycle with one temporary record.
  std::unique_ptr<Rec> tmp(new Rec);
  for (uint32_t p = 0; p < cnt; p++) {
    if (done[p] || ki[p].i == p) { done[p] = 1; continue; }
    std::memcpy(tmp.get(), &v[p], sizeof(Rec));
    uint32_t cur = p;
    for (;;) {
      uint32_t src = ki[cur].i;
      done[cur] = 1;
      if (src == p) { std::memcpy(&v[cur], tmp.get(), sizeof(Rec)); break; }
      std::memcpy(&v[cur], &v[src], sizeof(Rec));
      cur = src;
    }
  }
  auto t2 = clk::now();
  t_sort += secs(t0, t1);
  t_perm += secs(t1, t2);
}

int main(int argc, char **argv) {
  const long count = argc > 1 ? std::atol(argv[1]) : 16384;
  const int reps = argc > 2 ? std::atoi(argv[2]) : 1;

  auto t0 = clk::now();
  std::vector<Rec> v(count);  // value-initialised: the payload is zero, as the memset in the assignment
  for (long i = 0; i < count; i++) {
    key(v[i]) = (Key)(count - i);
    v[i].x[1] = (double)(count - i);  // tag: travels with the record, checked after sorting
  }
  double t_init = secs(t0, clk::now());

  double t_sort = 0, t_perm = 0;
  for (int r = 0; r < reps; r++) {
    bool ascending = (r % 2 == 0);
#if SPLIT
    sort_split(v, ascending, t_sort, t_perm);
#else
    sort_direct(v, ascending, t_sort, t_perm);
#endif
  }

  // Check: keys ordered in the direction of the last repetition and tags still attached.
  bool ok = true;
  if (reps > 0) {
    bool ascending = ((reps - 1) % 2 == 0);
    for (long i = 0; i < count && ok; i++) {
      if (v[i].x[1] != (double)key(v[i])) ok = false;
      if (i > 0 && (ascending ? key(v[i - 1]) > key(v[i]) : key(v[i - 1]) < key(v[i]))) ok = false;
    }
  }
  std::printf("variant=%s%s sizeof=%zu alignof=%zu count=%ld reps=%d init_s=%.6f "
              "sort_s=%.6f perm_s=%.6f per_rep_s=%.6f check=%s\n",
              layout_name, SPLIT_SUFFIX, sizeof(Rec), alignof(Rec), count, reps, t_init,
              t_sort, t_perm, reps ? (t_sort + t_perm) / reps : 0.0, ok ? "ok" : "FAIL");
  return ok ? 0 : 1;
}
