#!/usr/bin/env bash
# Post-edit auto-formatter hook (Claude Code PostToolUse on Edit|Write).
# Logs formatter errors to ~/.cache/agent-kit/format.log instead of failing silently.
# Always exits 0 so missing formatters never block edits.
set -euo pipefail

LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/agent-kit"
LOG_FILE="$LOG_DIR/format.log"

file="$(python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    ti = d.get("tool_input") or d.get("input") or {}
    if isinstance(ti, dict):
        print(ti.get("file_path") or ti.get("path") or "")
except Exception:
    pass
' 2>/dev/null || true)"

[[ -n "$file" && -f "$file" ]] || exit 0

run_fmt() {
  local out
  if ! out="$("$@" 2>&1)"; then
    mkdir -p "$LOG_DIR"
    printf '[%s] %s (%s): %s\n' "$(date -Iseconds)" "$*" "$file" "$out" >>"$LOG_FILE"
  fi
}

case "$file" in
  *.c|*.cc|*.cpp|*.cxx|*.h|*.hpp|*.hh)
    command -v clang-format >/dev/null 2>&1 && run_fmt clang-format -i "$file" ;;
  *.py)
    command -v ruff >/dev/null 2>&1 && run_fmt ruff format --quiet "$file" ;;
  *.ts|*.tsx|*.js|*.jsx)
    if command -v prettier >/dev/null 2>&1; then
      dir="$(dirname "$file")"
      if [[ -f "$dir/.prettierrc" || -f "$dir/.prettierrc.json" || -f "$dir/prettier.config.js" ]]; then
        run_fmt prettier --write --log-level silent "$file"
      fi
    fi ;;
esac

exit 0
