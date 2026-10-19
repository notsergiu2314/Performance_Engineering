# Variants compared (2026-10-16T10:00:50)

baseline archive: m3_baseline_34797; qa_ok: gate verdict of perf/results/m3_correctness_34937/correctness_rows.csv
variant base: binary md5 57396505a5e9, node cn17, job 34938: M3 baseline source and CFLAGS (measured in job 34797)
variant flags: binary md5 691e1555e193, node cn17, job 34938: T2 only: -fno-math-errno -fno-trapping-math (no kernel change)
variant cell: binary md5 06895463df66, node cn17, job 34938: flags + advec_cell register temporaries, dead post_vol store, reset/revert by field swap
variant mom: binary md5 b8de910ea938, node cn17, job 34938: flags + advec_mom helper hoist, dead pre_vol store, calc_dt fused reduction (not cell)
variant opt: binary md5 1594b80e3650, node cn17, job 34938: all changes (merge of cell and mom)

## Layouts (C kernels; reference variant: base; archive: m3_baseline_34797)

| layout | thp | archive m3_baseline_34797 | base | opt | opt/base speed-up | opt bytes vs base | base rerun drift vs archive |
|---|---|---|---|---|---|---|---|
| 1x128 | off | 13.31 s (13.28-13.92), 2.828 TB, 212 GB/s | 13.34 s (13.25-13.39), 2.828 TB, 212 GB/s | 10.43 s (10.28-10.52), 2.082 TB, 200 GB/s | 1.278x | -26.4 % | +0.2 % time, -0.0 % bytes |
| 1x128 | on | 26.91 s (17.44-29.20), 2.989 TB, 111 GB/s | 24.00 s (22.31-27.21), 2.959 TB, 123 GB/s | 19.33 s (14.51-24.39), 2.166 TB, 112 GB/s | 1.241x | -26.8 % | -10.8 % time, -1.0 % bytes |
| 4x32 | on | 13.00 s (12.76-13.21), 2.873 TB, 221 GB/s | 12.95 s (12.82-12.98), 2.866 TB, 221 GB/s | 9.95 s (9.87-10.13), 2.103 TB, 211 GB/s | 1.302x | -26.6 % | -0.3 % time, -0.3 % bytes |
| 32x4 | on | 11.46 s (11.41-11.47), 2.795 TB, 244 GB/s | 11.42 s (11.39-11.47), 2.795 TB, 245 GB/s | 8.45 s (8.43-8.52), 2.020 TB, 239 GB/s | 1.352x | -27.7 % | -0.4 % time, -0.0 % bytes |
| 64x2 | on | 11.32 s (11.24-11.33), 2.828 TB, 250 GB/s | 11.24 s (11.23-11.25), 2.827 TB, 251 GB/s | 8.24 s (8.23-8.36), 2.043 TB, 248 GB/s | 1.364x | -27.8 % | -0.6 % time, -0.0 % bytes |
| 128x1 | on | 11.66 s (11.63-11.77), 2.952 TB, 253 GB/s | 11.65 s (11.63-11.75), 2.952 TB, 253 GB/s | 8.44 s (8.43-8.45), 2.131 TB, 252 GB/s | 1.380x | -27.8 % | -0.1 % time, +0.0 % bytes |

Speed-up of opt against the archived baseline (the report's reference):

- 1x128 thp=off: 1.276x, bytes -26.4 %
- 1x128 thp=on: 1.392x, bytes -27.5 %
- 4x32 thp=on: 1.306x, bytes -26.8 %
- 32x4 thp=on: 1.357x, bytes -27.7 %
- 64x2 thp=on: 1.373x, bytes -27.8 %
- 128x1 thp=on: 1.381x, bytes -27.8 %

## Ladder at 64x2 (reference: base)

| variant | description | wall (s) | DRAM (TB) | GB/s | time vs ref | bytes vs ref |
|---|---|---|---|---|---|---|
| base | M3 baseline source and CFLAGS (measured in job 34797) | 11.310 (11.243-11.328) | 2.828 | 250 | +0.0 % | +0.0 % |
| flags | T2 only: -fno-math-errno -fno-trapping-math (no kernel change) | 11.283 (11.271-11.343) | 2.846 | 252 | -0.2 % | +0.7 % |
| cell | flags + advec_cell register temporaries, dead post_vol store, reset/revert by field swap | 9.922 (9.839-9.936) | 2.486 | 251 | -12.3 % | -12.1 % |
| mom | flags + advec_mom helper hoist, dead pre_vol store, calc_dt fused reduction (not cell) | 9.539 (9.537-9.617) | 2.405 | 252 | -15.7 % | -14.9 % |
| opt | all changes (merge of cell and mom) | 8.252 (8.231-8.326) | 2.043 | 248 | -27.0 % | -27.8 % |

## Byte-model prediction (report/data/plan.csv, all byte changes together)

- predicted: 1.983 TB (-29.3 % bytes), floor 7.44 s
- measured opt at 64x2: 2.043 TB (-27.8 % vs base), 8.25 s (-27.0 %)
- opt at 64x2 runs at 93 % of the 266 GB/s hardware ceiling; memory floor for its bytes 7.66 s

