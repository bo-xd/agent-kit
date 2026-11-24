---
name: perf-profiling
description: Measure-first performance profiling and optimization workflow for C/C++, systems, engines, and GPU/CUDA workloads. Use when optimizing hot paths, diagnosing latency, throughput, or memory bottlenecks, or investigating cache misses and stalls.
---

# Performance profiling & optimization

**Hard rule:** never optimize without a reproducible baseline measurement and an after measurement on the same workload.

## 1. Build for profiling (never profile `-O0`)

- CPU: `-O2 -g -fno-omit-frame-pointer` (keeps optimizations realistic while preserving call stacks).
- CMake: `-DCMAKE_BUILD_TYPE=RelWithDebInfo`.
- Pin CPU governor / close background noise for microbenchmarks; use `hyperfine` for CLI/frame-batch comparisons.

## 2. Pick the right tool

| Bottleneck / question | Tool |
|---|---|
| IPC, branch misses, L1/LLC cache misses | `perf stat -d ./bin <args>` |
| Where CPU time actually goes | `perf record -F 99 -g -- ./bin <args> && perf report` |
| Deterministic instruction / cache sim | `valgrind --tool=cachegrind ./bin <args>` |
| Heap allocations / peak RSS | `heaptrack ./bin <args>` or `valgrind --tool=massif` |
| Wall-clock A/B comparison | `hyperfine --warmup 3 './old' './new'` |
| GPU / CUDA timeline & kernels | `nsys profile -o trace ./bin` (timeline), `ncu --set full ./bin` (kernel) |

## 3. Optimization order (highest leverage first)

1. **Algorithm & work reduction** — do less work, hoist invariants, batch syscalls/draw calls.
2. **Memory layout & cache locality** — AoS → SoA for hot loops, contiguous arrays over pointer-chasing, keep hot structs small.
3. **Allocations** — pre-reserve, arena/pool allocators, eliminate per-frame `malloc`/`new`.
4. **Concurrency & SIMD** — remove lock contention/false sharing (align to 64B cache lines), check auto-vectorization (`-fopt-info-vec` / `-Rpass=loop-vectorize`).
5. **Micro-tweaks** — only after 1–4, and only if the profiler still points there.

## 4. Verify after every change

1. Re-run the exact benchmark (`hyperfine` / `perf stat` / frame timer) and report before → after numbers.
2. Re-run tests + ASan/UBSan (`c-cpp-debugging`) to prove the optimization didn't introduce UB.
