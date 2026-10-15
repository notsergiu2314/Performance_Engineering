# Report (LaTeX)

Draft of the performance-engineering report. Structure: 1 Introduction (short), 2 Baseline Analysis
(application/system, methodology, where the time goes, ceilings and byte model, baseline performance),
3 Kernel Improvements (selection, per-kernel count convention, every change as baseline code with comments, the
compile flags, implementation status with the new code), 4 Results (layouts against their baseline; filled from `data/optimised.csv` once measured),
5 Conclusions. THP gets one sentence and one table row (1x128 only).

| Path | What |
|---|---|
| `main.tex`, `refs.bib` | the report |
| `data/*.csv` | measured results, transcribed from the job outputs (each file names its job id) |
| `make_assets.py` | builds `figures/` and `tables/` from `data/` and from `../CloverLeaf_ref/perf/analysis/kernel_model.py` |
| `figures/*.pdf`, `tables/*.tex` | generated; included by `main.tex` |

## Rebuild the figures and tables
```
cd report
python3 make_assets.py       # needs matplotlib + numpy (on this laptop: /usr/bin/python3)
```
Nothing in `figures/` or `tables/` is edited by hand: change a CSV (or the model) and re-run.

## Compile
Upload `main.tex`, `refs.bib`, `figures/*.pdf` and `tables/*.tex` to Overleaf (same folder layout),
compiler pdfLaTeX, then bibliography with BibTeX (Overleaf does this automatically).

## M3 data files (branch `M3_dev`)

| File | Content | Produced by |
|---|---|---|
| `data/m3_baseline.csv` | 5 layouts x THP on/off, C and Fortran, median/min/max, DRAM TB, hardware GB/s | job 34797 (`perf/jobs/m3_baseline.sbatch`, 2026-10-13), aggregated from `results.csv` |
| `data/correctness.csv` | `clover_bm.in` baseline deviation per kernel set and layout | jobs 34729 and 34796 (`perf/jobs/m3_correctness.sbatch`, 7 of 7 ok) |
| `data/plan.csv` | predicted bytes of every planned C change (+ streaming-store bound); `tab_plan.tex` is generated but no longer included in the report | `python3 -I CloverLeaf_ref/perf/analysis/plan_bytes.py --csv report/data/plan.csv` |
| `data/ceilings.csv` rows `dram_node_counted_best`, `dram_node_hw`, `wa_ratio`, `dimm_mts_min` | hardware STREAM ceiling 266.5 GB/s, write-allocate check | job 34795 (`perf/jobs/m3_stream_ddrc.sbatch`) -> `ceilings_rows.csv` |
| `data/kernels_papi.csv` columns `*_64x2`, `*_1x128off` | per-kernel time, IPC, back-end stall at the M3 layouts | job 34798 (`perf/jobs/m3_papi.sbatch`) |
| `data/optimised.csv` (to be created) | `layout,ranks,threads,variant,n,median_s,min_s,max_s,dram_TB,qa_ok,source`: optimised build per layout, feeds `tab_results.tex` and the optimised bars of `fig_m3_layouts` | `m3_baseline.sbatch` on the optimised binary |

`benchmark_comparison_jort_vs_sergiu.md` is the comparison of the two M1/M2 branches that fixed
the M3 conventions (64x2 baseline, hardware bytes, correctness gate).

## Adding results later
* new measurements: add rows to the CSVs in `data/`, then `python make_assets.py`;
* M3 optimisation results go to `data/optimised.csv` (one row per layout and variant); `tab_results()` and
  `fig_m3_layouts()` pick them up automatically and compare with the `c / on` rows of `m3_baseline.csv`.
  `fig_scaling`, `fig_stream`, `fig_placement`, `tab_placement`, `tab_configs` are no longer in the report;
  their generators stay in `make_assets.py` (not called) and their data in `data/`.
