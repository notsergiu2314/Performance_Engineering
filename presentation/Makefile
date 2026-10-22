# Build the presentation: make (pdf), make notes (slides + speaker notes), make clean
SLIDES = main
TABLES = $(wildcard ../report/tables/tab_*.tex)

.PHONY: all notes clean

all: $(SLIDES).pdf

$(SLIDES).pdf: $(SLIDES).tex schematics.tex beamerthemeRUG.sty $(TABLES)
	latexmk -pdf -interaction=nonstopmode -halt-on-error $(SLIDES).tex

notes: $(SLIDES).tex schematics.tex beamerthemeRUG.sty $(TABLES)
	latexmk -pdf -interaction=nonstopmode -halt-on-error -jobname=$(SLIDES)_notes \
	  -usepretex='\PassOptionsToPackage{}{beamer}\AtBeginDocument{\setbeameroption{show notes on second screen=right}}' $(SLIDES).tex

clean:
	latexmk -C $(SLIDES).tex; rm -f $(SLIDES)_notes.*
