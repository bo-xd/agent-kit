CC ?= gcc
CFLAGS = -Wall -Wextra -Werror -fsanitize=address,undefined -g

test: packet.c tests.c
	$(CC) $(CFLAGS) packet.c tests.c -o test_bin
	./test_bin
