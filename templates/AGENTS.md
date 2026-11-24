# <Project name>

<!-- One or two sentences: what this project is and its current state.
     Delete every section that does not apply. Keep the whole file 30-80 lines.
     Global rules (read first, smallest change, verify) live elsewhere; don't repeat them. -->

<What it is, language/standard, target platform.>

## Commands

<!-- Only commands you have actually run successfully, or copied from CI. -->

- Build: `<e.g. cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build -j>`
- Test: `<e.g. ctest --test-dir build --output-on-failure>`
- Single test: `<e.g. ./build/tests/unit --gtest_filter=Lexer.*>`
- Run: `<e.g. ./build/app assets/demo.world>`
- Lint/format: `<e.g. clang-format -i $(git ls-files '*.c' '*.h'); clang-tidy -p build src/*.c>`
- Sanitizer build: `<e.g. cmake -S . -B build-asan -DCMAKE_C_FLAGS="-fsanitize=address,undefined -g">`

## Layout

- `src/` — <what lives here>
- `include/` — <public headers>
- `tests/` — <test framework, how tests are organised>
- `tools/` — <scripts, generators>

## Conventions

- <Language standard and compiler, e.g. C17, gcc and clang must both build warning-free with -Wall -Wextra>
- <Naming, error-handling style, e.g. functions return int error codes; no exceptions>
- <Memory/ownership rules, e.g. arena allocator per frame; never free chunk data directly>
- <Commit style, e.g. Conventional Commits>

## Do not

- <Generated or vendored files never edited by hand, e.g. `third_party/`, `src/gen/`>
- <Dangerous commands, e.g. never run `make flash` without asking>
- <Dependencies: ask before adding any new library>

## Gotchas

<!-- Things an agent got wrong before. One line each, add as they happen. -->

- <e.g. Tests need assets: run `./tools/fetch_assets.sh` once>
- <e.g. Kernel code is freestanding: no libc headers outside `lib/`>

## Done means

- <e.g. Build + tests pass in Debug and with ASan/UBSan; no new warnings; docs updated if behaviour changed>
