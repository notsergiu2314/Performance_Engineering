# Presentation (Beamer, RUG house style)

Target: 10 minutes talk + 5 minutes questions. 12 numbered slides, 5 backup slides (appendix, not counted).

| Path | What |
|---|---|
| `main.tex` | the slides; every frame has a `\note{}` with a time stamp and the one thing to say |
| `beamerthemeRUG.sty` | University of Groningen look: white, RUG red `#EE2425` (sampled from the wordmark), Open Sans, wordmark in the footer, red bar on the title page |
| `logo/rug_logo.png` | the official wordmark (from Wikipedia; replace with the vector logo from the RUG huisstijl portal if you have it) |
| `figures/*.pdf` | copies of `../report/figures/`; re-copy after `make_assets.py` |
| backup slides | `\input` the generated tables from `../report/tables/` directly |

Build: `make` (pdflatex via latexmk). `make notes` builds `main_notes.pdf` with the speaker notes on a second screen (use with pdfpc or Skim).
Overleaf: upload `main.tex`, `beamerthemeRUG.sty`, `logo/`, `figures/` and the four tables from `report/tables/` (adjust the `../report/tables/` paths).

Faculty accent colour: change `\definecolor{rugaccent}` in the theme.
