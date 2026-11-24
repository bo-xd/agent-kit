#include <stdlib.h>
#include <string.h>

typedef struct {
    char *buf;
    size_t len;
} Packet;

int log_packet(const Packet *p) {
    if (!p->buf) return 0;
    return (int)strlen(p->buf);
}

int process_packet(Packet *p) {
    if (p->len == 0) {
        free(p->buf);
    }
    return log_packet(p);
}
