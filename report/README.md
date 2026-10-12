# Report (LaTeX)

Draft of the performance-engineering report: M1 (analysis) and M2 (modelling) are written,
M3 (optimisations) is a placeholder in section 7.

| Path | What |
|---|---|
| `main.tex`, `refs.bib` | the report |
| `data/*.csv` | measured results, transcribed from the job outputs (each file names its job id) |
| `make_assets.py` | builds `figures/` and `tables/` from `data/` and from `../CloverLeaf_ref/perf/analysis/kernel_model.py` |
| `figures/*.pdf`, `tables/*.tex` | generated; included by `main.tex` |

## Rebuild the figures and tables
```
cd report
python make_assets.py        # needs matplotlib + numpy
```
Nothing in `figures/` or `tables/` is edited by hand: change a CSV (or the model) and re-run.

## Compile
Upload `main.tex`, `refs.bib`, `figures/*.pdf` and `tables/*.tex` to Overleaf (same folder layout),
compiler pdfLaTeX, then bibliography with BibTeX (Overleaf does this automatically).

## Adding results later
* new measurements: add rows to the CSVs in `data/`, then `python make_assets.py`;
* M3 results go to a new `data/optimisations.csv` and a new table/figure in `make_assets.py`.
