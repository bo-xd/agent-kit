#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    char *buf;
    size_t len;
} Packet;

static int log_packet(const Packet *p) {
    if (!p->buf) return 0;
    return (int)strlen(p->buf);
}

int process_packet(Packet *p) {
    if (p->len == 0) {
        free(p->buf);
    }
    return log_packet(p);
}

int main(void) {
    Packet p1 = { strdup("hello"), 5 };
    if (process_packet(&p1) != 5) return 1;
    free(p1.buf);

    Packet p2 = { strdup(""), 0 };
    if (process_packet(&p2) != 0) return 1;
    return 0;
}
