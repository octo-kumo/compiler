GCC=gcc
CFLAGS=-Wall -Wextra -std=gnu99 -g -DRUNTIME_DIR='"$(CURDIR)/src/c"'
SRCS=$(wildcard src/c/*.c)
HDRS=$(wildcard src/c/*.h)
OBJS=$(SRCS:src/c/%.c=src/c/%.o)
YBOOT=yboot
YCC_SRCS=src/y/ycc.y src/y/lexer.y src/y/parser.y src/y/types.y src/y/native.y src/y/arch_x64.y src/y/rename.y src/y/enc64.y src/y/asm.y src/y/elf.y src/y/std/io.y src/y/std/prelude.y

all: $(YBOOT)

$(YBOOT): $(OBJS)
	$(GCC) $(CFLAGS) -o $@ $^

src/c/%.o: src/c/%.c $(HDRS)
	$(GCC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(YBOOT) cycc ycc _ycc a.out
	rm -f $(SRCS:src/c/%.c=src/c/%.asan.o) yboot-asan

valgrind: $(YBOOT)
	valgrind --leak-check=full --quiet ./yboot
ASAN_FLAGS=-fsanitize=address,undefined -fno-omit-frame-pointer -g

yboot-asan: $(SRCS) $(HDRS)
	$(GCC) $(CFLAGS) $(ASAN_FLAGS) -o $@ $(SRCS)
asan: yboot-asan
test-asan: yboot-asan
	YBOOT=$(CURDIR)/yboot-asan ASAN_OPTIONS=detect_leaks=0 \
	    ./test/sh/run_all.sh $(SUITES_ASAN)
test: $(YBOOT) ycc
	./test/sh/run_all.sh $(SUITES)
test-fast: $(YBOOT)
	./test/sh/run_all.sh $(SUITES)
test-ycc: ycc
	./test/sh/test_ycc.sh
test-compile: $(YBOOT)
	./yboot --compile test/y/examples/helloworld.y -o /tmp/hello_bin && /tmp/hello_bin
cycc: $(YBOOT) $(YCC_SRCS) src/c/runtime.c src/c/runtime.h
	./yboot -S -o /tmp/ycc_boot.c src/y/ycc.y
	$(GCC) -O2 -std=gnu99 -Isrc/c -o cycc /tmp/ycc_boot.c src/c/runtime.c -lm
	@echo "stage-2: ./cycc built by yboot via C emission ($$(stat -c%s cycc) bytes)"
ycc: cycc $(YCC_SRCS)
	./cycc -o ycc src/y/ycc.y
	@echo "stage-3: ./ycc built by cycc, natively ($$(stat -c%s ycc) bytes)"
	./ycc -o _ycc src/y/ycc.y
	@echo "stage-4: _ycc built by ycc"
	cmp ycc _ycc
	rm -f _ycc
	@echo "fixpoint verified: ycc == _ycc (byte-identical) — ycc compiled by ycc"


.PHONY: all clean valgrind test test-fast test-ycc test-compile asan test-asan
