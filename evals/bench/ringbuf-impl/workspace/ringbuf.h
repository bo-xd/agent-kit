#ifndef RINGBUF_H
#define RINGBUF_H

#include <stddef.h>

typedef struct {
    int *data;
    size_t cap;
    size_t head;
    size_t tail;
    size_t count;
} RingBuf;

int rb_init(RingBuf *rb, int *backing, size_t cap);
int rb_push(RingBuf *rb, int val);   /* returns 0 on success, -1 if full */
int rb_pop(RingBuf *rb, int *out);   /* returns 0 on success, -1 if empty */

#endif
