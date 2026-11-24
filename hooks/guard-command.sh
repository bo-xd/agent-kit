#!/usr/bin/env bash
# Pre-tool safety guard for shell commands (Claude Code / Antigravity hooks).
# Reads JSON on stdin (expects {"tool_input":{"command":"..."}} or raw command).
# Exits 2 (block) on high-risk destructive patterns; 0 otherwise.
set -euo pipefail

input="$(cat)"
cmd="$(python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw)
    ti = d.get("tool_input") or d.get("input") or {}
    print(ti.get("command", "") if isinstance(ti, dict) else "")
except Exception:
    print(raw)
' <<<"$input")"

[[ -z "$cmd" ]] && exit 0

block() {
  echo "Blocked by agent-kit guard-command.sh: $1" >&2
  exit 2
}

# Destructive filesystem wipes targeting /, ~, $HOME, or ..
if grep -qE '(^|[;&|[:space:]])rm[[:space:]]+-[[:alnum:]]*r[[:alnum:]]*f?[[:space:]]+(/|~|\$HOME|\.\.)([[:space:];&|]|$)' <<<"$cmd"; then
  block "recursive rm on root, home, or parent directory"
fi

# Force push to main/master
if grep -qE 'git[[:space:]]+push[[:space:]].*(--force|-f)([[:space:]]|$)' <<<"$cmd" \
   && grep -qE '\b(main|master)\b' <<<"$cmd"; then
  block "force push to main/master"
fi

# Reading sensitive credential files directly via shell
if grep -qE '(\.ssh/id_|\.git-credentials|\.gnupg/|oauth_creds\.json)' <<<"$cmd"; then
  block "direct access to credential/key file"
fi

exit 0
