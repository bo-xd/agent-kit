#include <assert.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    char *buf;
    size_t len;
} Packet;

int process_packet(Packet *p);

int main(void) {
    Packet p1 = { strdup("hello"), 5 };
    assert(process_packet(&p1) == 5);
    free(p1.buf);

    Packet p2 = { strdup(""), 0 };
    assert(process_packet(&p2) == 0);
    return 0;
}
