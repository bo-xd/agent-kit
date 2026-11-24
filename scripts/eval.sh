#!/usr/bin/env bash
# Run live LLM evals for agent-kit skills using `claude plugin eval`.
# Passes any extra flags through (e.g. --case chunk, --ablation none).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

if ! command -v claude >/dev/null 2>&1; then
  echo "error: claude CLI not found" >&2
  exit 1
fi

exec claude plugin eval "$REPO" --eval-dir evals --trust-plugin "$@"
