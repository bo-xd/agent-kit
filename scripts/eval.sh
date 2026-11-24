#!/usr/bin/env bash
# Multi-agent eval runner for agent-kit (supports agy, codex, and claude).
# Defaults to running scripts/bench.py across available agents; pass
# --plugin-eval to run `claude plugin eval` on case.yaml suites instead.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

if [[ "${1:-}" == "--plugin-eval" ]]; then
  shift
  command -v claude >/dev/null 2>&1 || { echo "error: claude CLI not found" >&2; exit 1; }
  exec claude plugin eval "$REPO" --eval-dir evals --trust-plugin "$@"
fi

AGENTS=()
for a in agy codex claude; do
  command -v "$a" >/dev/null 2>&1 && AGENTS+=("$a")
done

if (( ${#AGENTS[@]} == 0 )); then
  echo "error: none of agy, codex, or claude found in PATH" >&2
  exit 1
fi

if [[ " $* " == *" --agents "* ]]; then
  exec python3 "$REPO/scripts/bench.py" "$@"
else
  exec python3 "$REPO/scripts/bench.py" --agents "${AGENTS[@]}" "$@"
fi
