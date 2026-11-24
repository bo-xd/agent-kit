---
name: c-cpp-debugging
description: Toolchain playbook for native C/C++ bugs with gcc/clang, CMake/Make, gdb, valgrind and sanitizers. Use when a C or C++ program segfaults, aborts, corrupts memory, leaks, hangs, races, behaves differently between debug and release builds, or a sanitizer/valgrind report needs interpreting.
---

# C/C++ Debugging

Tool layer for native bugs. For the investigation method itself (root cause before fix,
one hypothesis at a time) follow **systematic-debugging**; for the regression test follow
**test-driven-development**. This skill says *which tool, with which flags*.

## 1. Get a debuggable build first

Never debug an `-O2` build without symbols. Make a separate build dir per config.

```bash
# CMake
cmake -S . -B build-dbg -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_C_FLAGS="-g3 -O0 -fno-omit-frame-pointer" \
  -DCMAKE_CXX_FLAGS="-g3 -O0 -fno-omit-frame-pointer"
cmake --build build-dbg -j

# Make (if the Makefile honours CFLAGS/CXXFLAGS)
make clean && make CFLAGS="-g3 -O0 -fno-omit-frame-pointer" CXXFLAGS="-g3 -O0 -fno-omit-frame-pointer"
```

Turn on warnings before anything else — they often *are* the bug:
`-Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wnull-dereference -Wformat=2`.
Fix or understand every warning in the code you are touching.

## 2. Pick the tool by symptom

| Symptom | First tool |
|---|---|
| Segfault / abort, reproducible | ASan build, then gdb on the crash |
| Heap corruption, double free, use-after-free | ASan (`-fsanitize=address`) |
| Garbage values, "works in debug only" | UBSan + `-Wall -Wextra`; valgrind memcheck for uninit reads |
| Uninitialised memory reads | MSan (clang only, needs all deps instrumented) or `valgrind --track-origins=yes` |
| Leaks | ASan's LeakSanitizer (on by default on Linux) or `valgrind --leak-check=full` |
| Data race / flaky multithreaded | TSan (`-fsanitize=thread`, *not* combinable with ASan) |
| Hang / deadlock | `gdb -p <pid>` then `thread apply all bt` |
| Wrong result, no crash | gdb breakpoints + watchpoints; add asserts on invariants |
| Crash only in release | build `-O2 -g` + sanitizers; suspect UB, strict aliasing, uninit vars |
| Kernel / freestanding code | QEMU `-s -S` + `gdb` `target remote :1234`; serial printk logging |

## 3. Sanitizers

```bash
SAN="-fsanitize=address,undefined -fno-omit-frame-pointer -fno-sanitize-recover=all -g -O1"
cmake -S . -B build-asan -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_FLAGS="$SAN" -DCMAKE_CXX_FLAGS="$SAN" \
  -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined"
cmake --build build-asan -j

export ASAN_OPTIONS=abort_on_error=1:detect_leaks=1:strict_string_checks=1:detect_stack_use_after_return=1
export UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1
./build-asan/app
```

Reading an ASan report: the **first** stack is the bad access, "freed by" / "previously
allocated by" stacks tell you the object's lifetime. Fix the lifetime bug, not the line
that happened to touch freed memory.

## 4. gdb essentials

```bash
gdb -q --args ./build-dbg/app arg1 arg2
```

```
run                       # or: start (break at main)
bt full                   # backtrace with locals
frame 3 / up / down       # move through stack
info locals / p *ptr@n    # inspect; print n elements of an array
watch -l obj->field       # hardware watchpoint: who writes this?
break file.c:42 if i==7   # conditional breakpoint
catch throw               # C++ exceptions at throw site
thread apply all bt       # every thread (hangs, deadlocks)
set print pretty on
```

Core dumps on Arch (systemd): `coredumpctl list`, then `coredumpctl gdb <pid>`.
Reverse debugging for "how did it get here": `rr record ./app` then `rr replay`
(`reverse-continue`, `reverse-step`) if `rr` is installed.

## 5. valgrind (when sanitizers can't be rebuilt in)

```bash
valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --error-exitcode=1 ./build-dbg/app
valgrind --tool=helgrind ./build-dbg/app      # races/locks
valgrind --tool=callgrind ./build-dbg/app     # profiling; view with kcachegrind
```

Do not run valgrind on an ASan binary.

## 6. Engine / systems specifics

- **Simulation / rendering loops:** reproduce with a fixed seed and fixed timestep; dump the
  failing state. GPU issues: enable the API debug layer
  (Vulkan validation layers, `glDebugMessageCallback`) before blaming your code.
- **Compilers/lexers:** shrink the failing input first (delta-debug by hand or
  `creduce`/`cvise`), then trace token/AST state at the smallest input.
- **Kernel:** `-g` kernel build, QEMU gdbstub, `add-symbol-file` for modules; keep a
  serial log; triple faults → `qemu -d int,cpu_reset -no-reboot`.

## 7. Before calling it fixed

- [ ] Root cause explained in one sentence (lifetime, bounds, UB, race, logic).
- [ ] Regression test or minimal repro input added.
- [ ] Clean under ASan+UBSan (and TSan if threads were involved).
- [ ] No new warnings with the flags above.
- [ ] Release build (`-O2`) still passes — UB often hides at `-O0`.
