#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

size_t count_common(const int *a, size_t na, const int *b, size_t nb);

int main(void) {
    int s1[] = {1, 3, 5, 7};
    int s2[] = {2, 3, 7, 9};
    assert(count_common(s1, 4, s2, 4) == 2);
    assert(count_common(s1, 0, s2, 4) == 0);

    const size_t N = 100000;
    int *a = malloc(N * sizeof(int));
    int *b = malloc(N * sizeof(int));
    for (size_t i = 0; i < N; i++) {
        a[i] = (int)(i * 2);
        b[i] = (int)(i * 3);
    }

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    size_t got = count_common(a, N, b, N);
    clock_gettime(CLOCK_MONOTONIC, &t1);
    double ms = (t1.tv_sec - t0.tv_sec) * 1000.0 + (t1.tv_nsec - t0.tv_nsec) / 1e6;

    free(a);
    free(b);
    assert(got == 33334);
    if (ms > 50.0) {
        fprintf(stderr, "too slow: %.2f ms (budget 50 ms)\n", ms);
        return 1;
    }
    return 0;
}
