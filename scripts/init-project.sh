#!/usr/bin/env bash
# Bootstrap AGENTS.md + CLAUDE.md (@AGENTS.md) in a project directory.
# Marks unverified commands `# TODO: verify` unless --verify runs and passes them.
set -euo pipefail

FORCE=0
VERIFY=0
TARGET="."

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --verify) VERIFY=1 ;;
    -h|--help) echo "Usage: $(basename "$0") [--force] [--verify] [project-dir]"; exit 0 ;;
    *) TARGET="$arg" ;;
  esac
done

TARGET="$(cd "$TARGET" && pwd)"
PROJECT_NAME="$(basename "$TARGET")"

mark_cmd() {
  local cmd="$1"
  if [[ -z "$cmd" || "$cmd" == "<"* ]]; then
    printf '%s' "$cmd"
  elif (( VERIFY )) && (cd "$TARGET" && bash -c "$cmd" >/dev/null 2>&1); then
    printf '%s' "$cmd"
  else
    printf '%s  # TODO: verify' "$cmd"
  fi
}

if [[ -e "$TARGET/AGENTS.md" && "$FORCE" -eq 0 ]]; then
  echo "skip     $TARGET/AGENTS.md already exists (use --force to overwrite)"
else
  RAW_BUILD=""
  RAW_TEST=""
  RAW_LINT=""
  STACK="project"

  if [[ -f "$TARGET/build.sh" ]]; then
    STACK="shell build script"
    RAW_BUILD="./build.sh"
  elif [[ -f "$TARGET/CMakeLists.txt" ]]; then
    STACK="C/C++ (CMake)"
    RAW_BUILD="cmake -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build -j"
    if grep -qE 'enable_testing|add_test' "$TARGET/CMakeLists.txt" 2>/dev/null; then
      RAW_TEST="ctest --test-dir build --output-on-failure"
    fi
  elif [[ -f "$TARGET/Makefile" || -f "$TARGET/makefile" ]]; then
    STACK="Make"
    RAW_BUILD="make -j"
    grep -qE '^test:' "$TARGET"/[Mm]akefile 2>/dev/null && RAW_TEST="make test"
  elif [[ -f "$TARGET/Cargo.toml" ]]; then
    STACK="Rust (Cargo)"
    RAW_BUILD="cargo build"
    RAW_TEST="cargo test"
    RAW_LINT="cargo clippy -- -D warnings && cargo fmt --check"
  elif [[ -f "$TARGET/pyproject.toml" ]]; then
    STACK="Python"
    RAW_BUILD="uv sync"
    [[ -d "$TARGET/tests" || -d "$TARGET/test" ]] && RAW_TEST="pytest"
    command -v ruff >/dev/null 2>&1 && RAW_LINT="ruff check . && ruff format --check ."
  elif [[ -f "$TARGET/package.json" ]]; then
    STACK="Node / TypeScript"
    grep -q '"build"' "$TARGET/package.json" 2>/dev/null && RAW_BUILD="npm run build"
    grep -q '"test"' "$TARGET/package.json" 2>/dev/null && RAW_TEST="npm test"
  fi

  BUILD_CMD="${RAW_BUILD:+$(mark_cmd "$RAW_BUILD")}"
  TEST_CMD="${RAW_TEST:+$(mark_cmd "$RAW_TEST")}"
  LINT_CMD="${RAW_LINT:+$(mark_cmd "$RAW_LINT")}"
  [[ -z "$BUILD_CMD" ]] && BUILD_CMD="<build command>  # TODO: verify"
  [[ -z "$TEST_CMD" ]] && TEST_CMD="<test command>    # TODO: verify"

  LAYOUT=""
  for d in src include tests test docs scripts; do
    [[ -d "$TARGET/$d" ]] && LAYOUT+="- \`$d/\` — <describe>\n"
  done
  [[ -z "$LAYOUT" ]] && LAYOUT="- <list key directories/files here>\n"

  {
    printf '# AGENTS.md — %s\n\n' "$PROJECT_NAME"
    printf 'Detected stack: %s. Commands marked `# TODO: verify` have not been run here yet.\n\n' "$STACK"
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
