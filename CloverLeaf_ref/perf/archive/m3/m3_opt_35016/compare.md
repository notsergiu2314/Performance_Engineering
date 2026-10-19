# Variants compared (2026-10-19T15:30:57)

baseline archive: m3_baseline_34797; qa_ok: gate verdict of perf/results/m3_correctness_35012/correctness_rows.csv
variant base: binary md5 57396505a5e9, node cn15, job 35016: M3 baseline source and CFLAGS (measured in job 34797)
variant optnf: binary md5 50ed04ebf03c, node cn15, job 35016: opt with the baseline CFLAGS (no -fno-math-errno -fno-trapping-math)
variant pdv: binary md5 92033b95020d, node cn15, job 35016: optnf + PdV volume_change in a register (d2b00e6; measured in jobs 35012/35016/35017)

## Layouts (C kernels; reference variant: base; archive: m3_baseline_34797)

| layout | thp | archive m3_baseline_34797 | base | pdv | pdv/base speed-up | pdv bytes vs base | base rerun drift vs archive |
|---|---|---|---|---|---|---|---|
| 1x128 | off | 13.31 s (13.28-13.92), 2.828 TB, 212 GB/s | 13.32 s (13.18-14.00), 2.828 TB, 212 GB/s | 9.89 s (9.86-9.90), 1.980 TB, 200 GB/s | 1.347x | -30.0 % | +0.0 % time, -0.0 % bytes |
| 1x128 | on | 26.91 s (17.44-29.20), 2.989 TB, 111 GB/s | 25.52 s (17.03-31.11), 3.030 TB, 119 GB/s | 20.25 s (15.04-22.74), 2.094 TB, 103 GB/s | 1.261x | -30.9 % | -5.1 % time, +1.4 % bytes |
| 4x32 | on | 13.00 s (12.76-13.21), 2.873 TB, 221 GB/s | 13.02 s (12.89-13.38), 2.864 TB, 220 GB/s | 9.46 s (9.29-9.72), 2.002 TB, 212 GB/s | 1.377x | -30.1 % | +0.2 % time, -0.3 % bytes |
| 32x4 | on | 11.46 s (11.41-11.47), 2.795 TB, 244 GB/s | 11.39 s (11.38-11.46), 2.793 TB, 245 GB/s | 8.42 s (8.42-8.51), 1.977 TB, 235 GB/s | 1.352x | -29.2 % | -0.7 % time, -0.1 % bytes |
| 64x2 | on | 11.32 s (11.24-11.33), 2.828 TB, 250 GB/s | 11.31 s (11.22-11.31), 2.827 TB, 250 GB/s | 8.26 s (8.25-8.34), 2.012 TB, 244 GB/s | 1.369x | -28.8 % | -0.1 % time, -0.0 % bytes |
| 128x1 | on | 11.66 s (11.63-11.77), 2.952 TB, 253 GB/s | 11.76 s (11.62-11.76), 2.951 TB, 251 GB/s | 8.54 s (8.53-8.55), 2.110 TB, 247 GB/s | 1.376x | -28.5 % | +0.8 % time, -0.0 % bytes |

Speed-up of pdv against the archived baseline (the report's reference):

- 1x128 thp=off: 1.346x, bytes -30.0 %
- 1x128 thp=on: 1.329x, bytes -29.9 %
- 4x32 thp=on: 1.374x, bytes -30.3 %
- 32x4 thp=on: 1.361x, bytes -29.3 %
- 64x2 thp=on: 1.371x, bytes -28.9 %
- 128x1 thp=on: 1.365x, bytes -28.5 %

## Ladder at 64x2 (reference: base)

| variant | description | wall (s) | DRAM (TB) | GB/s | time vs ref | bytes vs ref |
|---|---|---|---|---|---|---|
| base | M3 baseline source and CFLAGS (measured in job 34797) | 11.224 (11.222-11.321) | 2.827 | 252 | +0.0 % | +0.0 % |
| optnf | opt with the baseline CFLAGS (no -fno-math-errno -fno-trapping-math) | 8.508 (8.502-8.587) | 2.052 | 241 | -24.2 % | -27.4 % |
| pdv | optnf + PdV volume_change in a register (d2b00e6; measured in jobs 35012/35016/35017) | 8.253 (8.251-8.372) | 2.012 | 244 | -26.5 % | -28.8 % |

## Byte-model prediction (report/data/plan.csv, all byte changes together)

- predicted: 1.983 TB (-29.3 % bytes), floor 7.44 s
- measured pdv at 64x2: 2.012 TB (-28.8 % vs base), 8.25 s (-26.5 %)
- pdv at 64x2 runs at 91 % of the 266 GB/s hardware ceiling; memory floor for its bytes 7.55 s

