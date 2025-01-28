CFLAGS  = -Ilocal/include -O0 -g -Wall -Werror -lpthread
#CFLAGS += -DSET_CPU_AFFINITY
HEADERS = $(wildcard src/*.h)
CC     ?= gcc

all: ccat bench.sc bench.opt

clean:
	rm -rf ccat bench.* *.ll src/*.ll *.jpg

ccat: src/ccat.c $(HEADERS)
	$(CC) $(CFLAGS) -o $@ $<

bench.sc: src/bench.c $(HEADERS)
	$(CC) $(CFLAGS) -o $@ src/bench.c

bench.opt: src/bench.c $(HEADERS)
	$(CC) $(CFLAGS) -DOPTIMIZED -o $@ src/bench.c

.PHONY: all clean
