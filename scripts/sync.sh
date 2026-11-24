#!/usr/bin/env bash
# One-command sync for agent-kit: fast-forward pull (if clean), re-run
# install.sh, update third-party skills/plugins, and verify all links.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINKS_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --links-only) LINKS_ONLY=1 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--links-only]"
      exit 0
      ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [[ -z "$(git -C "$REPO" status --porcelain)" ]]; then
  echo "==> git pull --ff-only"
  git -C "$REPO" pull --ff-only || echo "warn: git pull skipped (offline or diverged)"
else
  echo "warn: working tree has uncommitted changes; skipping git pull"
fi

if (( LINKS_ONLY )); then
  "$REPO/install.sh" --links-only
else
  "$REPO/install.sh"
  if command -v npx >/dev/null 2>&1; then
    echo "==> updating third-party skills"
    npx -y skills update -g -y </dev/null || echo "warn: skills update failed"
  fi
  if command -v claude >/dev/null 2>&1; then
    echo "==> updating Claude marketplaces"
    claude plugin marketplace update 2>/dev/null || true
  fi
fi

echo "==> checking links"
"$REPO/install.sh" --check
