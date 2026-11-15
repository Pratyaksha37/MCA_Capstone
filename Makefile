SHELL := /bin/bash

.PHONY: all test synthesis clean

all: test synthesis

test:
	./scripts/run_tests.sh

synthesis:
	./scripts/run_synthesis.sh

clean:
	rm -f results/simulation/*.vvp
	rm -f results/simulation/*.log
	rm -f results/simulation/*.txt
	rm -f results/waveforms/*.vcd
	rm -f results/synthesis/*.log
	rm -f results/synthesis/*.txt
	rm -f results/performance/*.txt
	rm -f results/performance/*.log
