# Build the assignment report: make (pdf), make clean
REPORT = lab_5

.PHONY: all clean

all: $(REPORT).pdf

$(REPORT).pdf: $(REPORT).tex
	latexmk -pdf -interaction=nonstopmode -halt-on-error $(REPORT).tex

clean:
	latexmk -C $(REPORT).tex
