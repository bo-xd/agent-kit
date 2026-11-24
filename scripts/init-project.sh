#!/usr/bin/env bash
# Bootstrap AGENTS.md + CLAUDE.md (@AGENTS.md) in a project directory.
# Inspects actual files/dirs before writing commands; never overwrites without --force.
set -euo pipefail

FORCE=0
TARGET="."

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help) echo "Usage: $(basename "$0") [--force] [project-dir]"; exit 0 ;;
    *) TARGET="$arg" ;;
  esac
done

TARGET="$(cd "$TARGET" && pwd)"
PROJECT_NAME="$(basename "$TARGET")"

if [[ -e "$TARGET/AGENTS.md" && "$FORCE" -eq 0 ]]; then
  echo "skip     $TARGET/AGENTS.md already exists (use --force to overwrite)"
else
  BUILD_CMD="<build command>  # TODO: verify"
  TEST_CMD="<test command>    # TODO: verify"
  LINT_CMD=""
  STACK="project"

  if [[ -f "$TARGET/build.sh" ]]; then
    STACK="shell build script"
    BUILD_CMD="./build.sh  # TODO: verify"
  elif [[ -f "$TARGET/CMakeLists.txt" ]]; then
    STACK="C/C++ (CMake)"
    BUILD_CMD="cmake -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build -j"
    if grep -qE 'enable_testing|add_test' "$TARGET/CMakeLists.txt" 2>/dev/null; then
      TEST_CMD="ctest --test-dir build --output-on-failure"
    fi
  elif [[ -f "$TARGET/Makefile" || -f "$TARGET/makefile" ]]; then
    STACK="Make"
    BUILD_CMD="make -j"
    grep -qE '^test:' "$TARGET"/[Mm]akefile 2>/dev/null && TEST_CMD="make test"
  elif [[ -f "$TARGET/Cargo.toml" ]]; then
    STACK="Rust (Cargo)"
    BUILD_CMD="cargo build"
    TEST_CMD="cargo test"
    LINT_CMD="cargo clippy -- -D warnings && cargo fmt --check"
  elif [[ -f "$TARGET/pyproject.toml" ]]; then
    STACK="Python"
    BUILD_CMD="uv sync  # TODO: verify"
    [[ -d "$TARGET/tests" || -d "$TARGET/test" ]] && TEST_CMD="pytest"
    command -v ruff >/dev/null 2>&1 && LINT_CMD="ruff check . && ruff format --check ."
  elif [[ -f "$TARGET/package.json" ]]; then
    STACK="Node / TypeScript"
    BUILD_CMD="npm run build  # TODO: verify"
    grep -q '"test"' "$TARGET/package.json" 2>/dev/null && TEST_CMD="npm test"
  fi

  LAYOUT=""
  for d in src include tests test docs scripts; do
    [[ -d "$TARGET/$d" ]] && LAYOUT+="- \`$d/\` — <describe>\n"
  done
  [[ -z "$LAYOUT" ]] && LAYOUT="- <list key directories/files here>\n"

  {
    printf '# AGENTS.md — %s\n\n' "$PROJECT_NAME"
    printf 'Detected stack: %s. Replace placeholders and `# TODO: verify` after running.\n\n' "$STACK"
    printf '## Commands\n'
    printf -- '- **Build:** `%s`\n' "$BUILD_CMD"
    printf -- '- **Test:** `%s`\n' "$TEST_CMD"
    [[ -n "$LINT_CMD" ]] && printf -- '- **Lint / format:** `%s`\n' "$LINT_CMD"
    printf '\n## Layout\n%b\n' "$LAYOUT"
    printf '## Conventions\n- Keep changes minimal and scoped to the request.\n\n'
    printf '## Do not\n- Do not commit secrets or build artifacts.\n- Do not add dependencies without asking first.\n\n'
    printf '## Gotchas\n- <add project-specific invariants or tricky flags here>\n\n'
    printf '## Done means\n- Build and test commands above pass after the final edit.\n'
  } >"$TARGET/AGENTS.md"
  echo "created  $TARGET/AGENTS.md ($STACK)"
fi

if [[ -e "$TARGET/CLAUDE.md" && "$FORCE" -eq 0 ]]; then
  echo "skip     $TARGET/CLAUDE.md already exists"
else
  printf '@AGENTS.md\n' >"$TARGET/CLAUDE.md"
  echo "created  $TARGET/CLAUDE.md (@AGENTS.md pointer)"
fi
