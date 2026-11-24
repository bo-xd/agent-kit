#include <stddef.h>

/* Both arrays are sorted ascending and contain distinct integers. */
size_t count_common(const int *a, size_t na, const int *b, size_t nb) {
    size_t hits = 0;
    for (size_t i = 0; i < na; i++) {
        for (size_t j = 0; j < nb; j++) {
            if (a[i] == b[j]) hits++;
        }
    }
    return hits;
}
