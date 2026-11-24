#include "ringbuf.h"

int rb_init(RingBuf *rb, int *backing, size_t cap) {
    (void)rb; (void)backing; (void)cap;
    return -1;
}

int rb_push(RingBuf *rb, int val) {
    (void)rb; (void)val;
    return -1;
}

int rb_pop(RingBuf *rb, int *out) {
    (void)rb; (void)out;
    return -1;
}
