CC ?= gcc
CFLAGS = -O2 -Wall -Wextra -Werror

test: hotloop.c tests.c
	$(CC) $(CFLAGS) hotloop.c tests.c -o test_bin
	./test_bin
