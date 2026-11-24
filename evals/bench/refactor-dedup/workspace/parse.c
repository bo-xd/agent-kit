#include <stdint.h>

int parse_u16_dec(const char *s, uint16_t *out) {
    if (!s || !*s) return -1;
    uint32_t acc = 0;
    for (; *s; s++) {
        if (*s < '0' || *s > '9') return -1;
        acc = acc * 10u + (uint32_t)(*s - '0');
        if (acc > 65535u) return -1;
    }
    *out = (uint16_t)acc;
    return 0;
}

int parse_u16_hex(const char *s, uint16_t *out) {
    if (!s || !*s) return -1;
    uint32_t acc = 0;
    for (; *s; s++) {
        uint32_t d;
        if (*s >= '0' && *s <= '9') d = (uint32_t)(*s - '0');
        else if (*s >= 'a' && *s <= 'f') d = (uint32_t)(*s - 'a' + 10);
        else if (*s >= 'A' && *s <= 'F') d = (uint32_t)(*s - 'A' + 10);
        else return -1;
        acc = acc * 16u + d;
        if (acc > 65535u) return -1;
    }
    *out = (uint16_t)acc;
    return 0;
}
