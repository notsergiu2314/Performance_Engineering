# Lab 7 ex1: one binary per data-structure variant (see ds_bench.cpp for the list).
#   make            build all variants into bin/
#   make CXX=g++ CXXFLAGS="-O2 -std=c++17 -mcpu=native"
CXX      ?= g++
CXXFLAGS ?= -O2 -std=c++17 -march=native
BIN      ?= bin

# *_base: layout of the assignment; *_opt: all optimizations combined (what the report uses);
# the others isolate one technique each.
VARIANTS = small_base small_opt small_reorder small_align small_split big_base big_opt big_pad big_split
TARGETS  = $(addprefix $(BIN)/,$(VARIANTS))

.PHONY: all clean
all: $(TARGETS)

$(BIN)/small_base:    DEFS = -DLAYOUT=SMALL_BASE    -DSPLIT=0
$(BIN)/small_reorder: DEFS = -DLAYOUT=SMALL_REORDER -DSPLIT=0
$(BIN)/small_align:   DEFS = -DLAYOUT=SMALL_ALIGN   -DSPLIT=0
$(BIN)/small_split:   DEFS = -DLAYOUT=SMALL_BASE    -DSPLIT=1
$(BIN)/small_opt:     DEFS = -DLAYOUT=SMALL_ALIGN   -DSPLIT=1
$(BIN)/big_base:      DEFS = -DLAYOUT=BIG_BASE      -DSPLIT=0
$(BIN)/big_pad:       DEFS = -DLAYOUT=BIG_PAD       -DSPLIT=0
$(BIN)/big_split:     DEFS = -DLAYOUT=BIG_BASE      -DSPLIT=1
$(BIN)/big_opt:       DEFS = -DLAYOUT=BIG_PAD       -DSPLIT=1

$(TARGETS): ds_bench.cpp | $(BIN)
	$(CXX) $(CXXFLAGS) $(DEFS) $< -o $@

$(BIN):
	mkdir -p $(BIN)

clean:
	rm -rf $(BIN)
