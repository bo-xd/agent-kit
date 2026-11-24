#include "ringbuf.h"
#include <assert.h>

int main(void) {
    int buf[3];
    RingBuf rb;
    assert(rb_init(&rb, buf, 0) == -1);
    assert(rb_init(&rb, buf, 3) == 0);

    int out = 0;
    assert(rb_pop(&rb, &out) == -1);
    assert(rb_push(&rb, 10) == 0);
    assert(rb_push(&rb, 20) == 0);
    assert(rb_push(&rb, 30) == 0);
    assert(rb_push(&rb, 40) == -1);

    assert(rb_pop(&rb, &out) == 0 && out == 10);
    assert(rb_push(&rb, 40) == 0);
    assert(rb_pop(&rb, &out) == 0 && out == 20);
    assert(rb_pop(&rb, &out) == 0 && out == 30);
    assert(rb_pop(&rb, &out) == 0 && out == 40);
    assert(rb_pop(&rb, &out) == -1);
    return 0;
}
