# Presentation (Beamer, RUG house style)

Target: 15 minutes talk, scripted slide by slide in `script.md`. 14 numbered slides, no backup slides.

| Path | What |
|---|---|
| `main.tex` | the slides; every frame has a `\note{}` with a time stamp and the one thing to say |
| `script.md` | the spoken script per slide, with the start time and length of each slide (the `\note{}` time stamps match it) |
| `schematics.tex` | the two data-flow slides (TikZ before/after schematics of the byte changes), `\input` after the plan slide; presentation only |
| `beamerthemeRUG.sty` | University of Groningen look: white, RUG red `#EE2425` (sampled from the wordmark), Open Sans, wordmark in the footer, red bar on the title page |
| `logo/rug_logo.png` | the official wordmark (from Wikipedia; replace with the vector logo from the RUG huisstijl portal if you have it) |
| `figures/*.pdf` | copies of `../report/figures/`; re-copy after `make_assets.py` |
| `../report/tables/` | the Baseline, Plan and Ladder slides `\input` `tab_m3_baseline`, `tab_plan` and `tab_ladder` from here, so they follow `make_assets.py` without copying |

Build: `make` (pdflatex via latexmk). `make notes` builds `main_notes.pdf` with the speaker notes on a second screen (use with pdfpc or Skim).
Overleaf: upload `main.tex`, `schematics.tex`, `beamerthemeRUG.sty`, `logo/`, `figures/`; the three tables are read from `../report/tables/`, outside this folder, so they have to be uploaded too with that relative path intact (or build locally).

Faculty accent colour: change `\definecolor{rugaccent}` in the theme.
