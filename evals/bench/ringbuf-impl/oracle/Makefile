CC ?= gcc
CFLAGS = -Wall -Wextra -Werror -fsanitize=address,undefined -g

test: ringbuf.c tests.c
	$(CC) $(CFLAGS) ringbuf.c tests.c -o test_bin
	./test_bin
