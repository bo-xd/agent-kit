CC ?= gcc
CFLAGS = -Wall -Wextra -Werror -fsanitize=address,undefined -g

test: parse.c tests.c
	$(CC) $(CFLAGS) parse.c tests.c -o test_bin
	./test_bin
