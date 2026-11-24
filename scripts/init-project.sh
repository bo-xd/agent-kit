#!/usr/bin/env bash
# Bootstrap AGENTS.md + CLAUDE.md (@AGENTS.md) in a project directory.
# Detects the primary build/test stack without overwriting existing files
# unless --force is passed.
set -euo pipefail

FORCE=0
TARGET="."

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--force] [project-dir]"
      exit 0
      ;;
    *) TARGET="$arg" ;;
  esac
done

TARGET="$(cd "$TARGET" && pwd)"
PROJECT_NAME="$(basename "$TARGET")"

if [[ -e "$TARGET/AGENTS.md" && "$FORCE" -eq 0 ]]; then
  echo "skip     $TARGET/AGENTS.md already exists (use --force to overwrite)"
else
  BUILD_CMD="<build command>"
  TEST_CMD="<test command>"
  LINT_CMD="<lint/format command>"
  STACK="project"

  if [[ -f "$TARGET/CMakeLists.txt" ]]; then
    STACK="C/C++ (CMake)"
    BUILD_CMD="cmake -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build -j"
    TEST_CMD="ctest --test-dir build --output-on-failure"
    LINT_CMD="clang-format --dry-run --Werror src/*.[ch]*"
  elif [[ -f "$TARGET/Makefile" || -f "$TARGET/makefile" ]]; then
    STACK="C/C++ (Make)"
    BUILD_CMD="make -j"
    TEST_CMD="make test"
    LINT_CMD="make lint"
  elif [[ -f "$TARGET/Cargo.toml" ]]; then
    STACK="Rust (Cargo)"
    BUILD_CMD="cargo build"
    TEST_CMD="cargo test"
    LINT_CMD="cargo clippy -- -D warnings && cargo fmt --check"
  elif [[ -f "$TARGET/pyproject.toml" ]]; then
    STACK="Python"
    BUILD_CMD="uv sync"
    TEST_CMD="pytest"
    LINT_CMD="ruff check . && ruff format --check ."
  elif [[ -f "$TARGET/package.json" ]]; then
    STACK="Node / TypeScript"
    BUILD_CMD="npm run build"
    TEST_CMD="npm test"
    LINT_CMD="npm run lint"
  fi

  cat >"$TARGET/AGENTS.md" <<EOF
# AGENTS.md — $PROJECT_NAME

Detected stack: $STACK. Edit commands and gotchas below to match reality.

## Commands
- **Build:** \`$BUILD_CMD\`
- **Test:** \`$TEST_CMD\`
- **Lint / format:** \`$LINT_CMD\`

## Layout
- \`src/\` — main source
- \`tests/\` — test suite

## Conventions
- Keep changes minimal and scoped to the request.
- Follow existing naming, error-handling, and formatting style.

## Do not
- Do not commit secrets, build artifacts, or generated files.
- Do not add new dependencies without asking first.

## Gotchas
- <add project-specific invariants or tricky build flags here>

## Done means
- Build and test commands above pass after the final edit.
EOF
  echo "created  $TARGET/AGENTS.md ($STACK)"
fi

if [[ -e "$TARGET/CLAUDE.md" && "$FORCE" -eq 0 ]]; then
  echo "skip     $TARGET/CLAUDE.md already exists"
else
  printf '@AGENTS.md\n' >"$TARGET/CLAUDE.md"
  echo "created  $TARGET/CLAUDE.md (@AGENTS.md pointer)"
fi
