#!/usr/bin/env bash
# Post-edit auto-formatter hook (Claude Code PostToolUse on Edit|Write).
# Reads JSON on stdin, extracts the edited file path, and formats it if a
# matching formatter is installed. Always exits 0 so missing tools never block.
set -euo pipefail

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

case "$file" in
  *.c|*.cc|*.cpp|*.cxx|*.h|*.hpp|*.hh)
    if command -v clang-format >/dev/null 2>&1; then
      clang-format -i "$file" 2>/dev/null || true
    fi
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      ruff format --quiet "$file" 2>/dev/null || true
    fi
    ;;
  *.ts|*.tsx|*.js|*.jsx)
    if command -v prettier >/dev/null 2>&1; then
      dir="$(dirname "$file")"
      if [[ -f "$dir/.prettierrc" || -f "$dir/.prettierrc.json" || -f "$dir/prettier.config.js" ]]; then
        prettier --write --log-level silent "$file" 2>/dev/null || true
      fi
    fi
    ;;
esac

exit 0
