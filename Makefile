CFLAGS  = -Ilocal/include -O0 -g -Wall -Werror -lpthread
#CFLAGS += -DSET_CPU_AFFINITY
HEADERS = $(wildcard src/*.h)
CC     ?= gcc

all: ccat

clean:
	rm -rf ccat *.ll src/*.ll *.jpg

ccat: src/ccat.c $(HEADERS)
	$(CC) $(CFLAGS) -o $@ $<

.PHONY: all clean
