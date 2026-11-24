CC ?= gcc
CFLAGS = -Wall -Wextra -Werror -fsanitize=address,undefined -g

test: main.c
	$(CC) $(CFLAGS) main.c -o test_bin
	./test_bin

clean:
	rm -f test_bin
