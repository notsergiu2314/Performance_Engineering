# Variants compared (2026-10-19T13:27:39)

baseline archive: m3_baseline_34797; qa_ok: gate verdict of perf/results/m3_correctness_35002/correctness_rows.csv
variant base: binary md5 57396505a5e9, node cn16, job 35003: M3 baseline source and CFLAGS (measured in job 34797)
variant opt: binary md5 1594b80e3650, node cn16, job 35003: all changes (merge of cell and mom)
variant optnf: binary md5 50ed04ebf03c, node cn16, job 35003: opt with the baseline CFLAGS (no -fno-math-errno -fno-trapping-math)

## Layouts (C kernels; reference variant: base; archive: m3_baseline_34797)

| layout | thp | archive m3_baseline_34797 | base | optnf | optnf/base speed-up | optnf bytes vs base | base rerun drift vs archive |
|---|---|---|---|---|---|---|---|
| 1x128 | off | 13.31 s (13.28-13.92), 2.828 TB, 212 GB/s | 13.39 s (13.23-13.44), 2.829 TB, 211 GB/s | 10.16 s (10.13-10.77), 2.029 TB, 200 GB/s | 1.318x | -28.3 % | +0.6 % time, +0.0 % bytes |
| 1x128 | on | 26.91 s (17.44-29.20), 2.989 TB, 111 GB/s | 27.61 s (17.27-28.88), 2.991 TB, 108 GB/s | 17.84 s (12.87-23.16), 2.115 TB, 119 GB/s | 1.548x | -29.3 % | +2.6 % time, +0.1 % bytes |
| 4x32 | on | 13.00 s (12.76-13.21), 2.873 TB, 221 GB/s | 13.15 s (13.01-13.23), 2.870 TB, 218 GB/s | 9.79 s (9.63-9.94), 2.052 TB, 210 GB/s | 1.344x | -28.5 % | +1.2 % time, -0.1 % bytes |
| 32x4 | on | 11.46 s (11.41-11.47), 2.795 TB, 244 GB/s | 11.40 s (11.40-11.47), 2.794 TB, 245 GB/s | 8.70 s (8.69-8.77), 2.010 TB, 231 GB/s | 1.311x | -28.1 % | -0.5 % time, -0.0 % bytes |
| 64x2 | on | 11.32 s (11.24-11.33), 2.828 TB, 250 GB/s | 11.24 s (11.24-11.27), 2.828 TB, 252 GB/s | 8.55 s (8.53-8.63), 2.052 TB, 240 GB/s | 1.315x | -27.4 % | -0.6 % time, +0.0 % bytes |
| 128x1 | on | 11.66 s (11.63-11.77), 2.952 TB, 253 GB/s | 11.76 s (11.65-11.79), 2.952 TB, 251 GB/s | 8.81 s (8.79-8.82), 2.148 TB, 244 GB/s | 1.335x | -27.2 % | +0.8 % time, +0.0 % bytes |

Speed-up of optnf against the archived baseline (the report's reference):

- 1x128 thp=off: 1.310x, bytes -28.3 %
- 1x128 thp=on: 1.508x, bytes -29.3 %
- 4x32 thp=on: 1.328x, bytes -28.6 %
- 32x4 thp=on: 1.318x, bytes -28.1 %
- 64x2 thp=on: 1.324x, bytes -27.4 %
- 128x1 thp=on: 1.324x, bytes -27.2 %

## Ladder at 64x2 (reference: base)

| variant | description | wall (s) | DRAM (TB) | GB/s | time vs ref | bytes vs ref |
|---|---|---|---|---|---|---|
| base | M3 baseline source and CFLAGS (measured in job 34797) | 11.317 (11.259-11.349) | 2.828 | 250 | +0.0 % | +0.0 % |
| opt | all changes (merge of cell and mom) | 8.252 (8.242-8.354) | 2.043 | 248 | -27.1 % | -27.8 % |
| optnf | opt with the baseline CFLAGS (no -fno-math-errno -fno-trapping-math) | 8.563 (8.533-8.634) | 2.052 | 240 | -24.3 % | -27.4 % |

## Byte-model prediction (report/data/plan.csv, all byte changes together)

- predicted: 1.983 TB (-29.3 % bytes), floor 7.44 s
- measured optnf at 64x2: 2.052 TB (-27.4 % vs base), 8.56 s (-24.3 %)
- opt at 64x2 runs at 90 % of the 266 GB/s hardware ceiling; memory floor for its bytes 7.70 s

