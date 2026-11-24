#include <assert.h>
#include <stdint.h>

int parse_u16_dec(const char *s, uint16_t *out);
int parse_u16_hex(const char *s, uint16_t *out);

int main(void) {
    uint16_t v = 0;
    assert(parse_u16_dec("0", &v) == 0 && v == 0);
    assert(parse_u16_dec("65535", &v) == 0 && v == 65535);
    assert(parse_u16_dec("65536", &v) == -1);
    assert(parse_u16_dec("", &v) == -1);
    assert(parse_u16_dec("12a", &v) == -1);

    assert(parse_u16_hex("0", &v) == 0 && v == 0);
    assert(parse_u16_hex("ffff", &v) == 0 && v == 65535);
    assert(parse_u16_hex("10000", &v) == -1);
    assert(parse_u16_hex("AbCd", &v) == 0 && v == 0xabcd);
    assert(parse_u16_hex("xyz", &v) == -1);
    return 0;
}
