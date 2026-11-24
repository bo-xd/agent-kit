#!/usr/bin/env bash
# Install Bo's AI setup: symlink rules, skills, agents and MCP config into every
# tool's config dir, then install third-party skills, Claude plugins and MCP
# servers via their CLIs. Idempotent. See README.md.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.ai-setup-backups/$TS"

DRY_RUN=0
CHECK=0
LINKS_ONLY=0
NOT_OK=0

usage() {
  cat <<EOF
Usage: ./install.sh [--dry-run] [--check] [--links-only] [--help]

  (no flags)    create all links, then run the npx / claude / codex steps
  --dry-run     print every action, change nothing
  --check       report each link as OK / MISSING / WRONG; exit 1 if any is not OK
  --links-only  only create links; skip the npx / claude / codex steps
  --help        show this help

Existing files or foreign symlinks at a target are moved to
~/.ai-setup-backups/<timestamp>/<same relative path> before linking.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --check) CHECK=1 ;;
    --links-only) LINKS_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }

# Run a command, or only print it in --dry-run mode.
run() {
  if (( DRY_RUN )); then
    say "[dry-run] $*"
  else
    "$@"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# Run a read-only status query. Skipped in --dry-run (the claude CLI writes to
# ~/.claude.json even for queries), so dry-run reports every item as "ensure".
query() {
  (( DRY_RUN )) && return 1
  "$@"
}

# ensure <description> <command...>: run command, or in --dry-run print it as "if missing".
ensure() {
  local what="$1"; shift
  if (( DRY_RUN )); then
    say "[dry-run] $* (if $what is missing)"
  else
    "$@"
  fi
}

# link <source in repo> <target path>
link() {
  local src="$1" dst="$2"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    (( CHECK )) && say "OK       $dst"
    return 0
  fi
  if (( CHECK )); then
    if [[ -e "$dst" || -L "$dst" ]]; then
      say "WRONG    $dst (expected -> $src)"
    else
      say "MISSING  $dst"
    fi
    NOT_OK=1
    return 0
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    local backup="$BACKUP_DIR/${dst#"$HOME"/}"
    say "backup   $dst -> $backup"
    run mkdir -p "$(dirname "$backup")"
    run mv "$dst" "$backup"
  fi
  say "link     $dst -> $src"
  run mkdir -p "$(dirname "$dst")"
  run ln -s "$src" "$dst"
}

# Lines of a list file with comments and blank lines removed.
list_lines() {
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$1"
}

do_links() {
  local f d name
  for f in "$HOME/.gemini/GEMINI.md" "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md"; do
    link "$REPO/rules/global.md" "$f"
  done

  shopt -s nullglob
  for d in "$REPO"/skills/*/; do
    name="$(basename "$d")"
    link "$REPO/skills/$name" "$HOME/.agents/skills/$name"
    link "$REPO/skills/$name" "$HOME/.claude/skills/$name"
  done

  for f in "$REPO"/agents/antigravity/*.md; do
    link "$f" "$HOME/.gemini/config/agents/$(basename "$f")"
  done
  shopt -u nullglob

  link "$REPO/mcp/servers.json" "$HOME/.gemini/config/mcp_config.json"
  link "$REPO/mcp/servers.json" "$HOME/.cursor/mcp.json"
}

do_skill_packs() {
  if ! have npx; then say "skip     third-party skills (npx not found)"; return 0; fi
  local line args
  while IFS= read -r line; do
    read -ra args <<<"$line"
    say "skills   $line"
    run npx -y skills add "${args[@]}" -g -y </dev/null
  done < <(list_lines "$REPO/skills.txt")
}

# True if `claude ... list` output has an entry line "❯ <name>".
listed() { awk -v n="$2" '$1 == "❯" && $2 == n { found = 1 } END { exit !found }' <<<"$1"; }

do_claude_plugins() {
  if ! have claude; then say "skip     claude plugins (claude not found)"; return 0; fi
  local markets plugins kind a b
  markets="$(query claude plugin marketplace list 2>/dev/null || true)"
  plugins="$(query claude plugin list 2>/dev/null || true)"
  while read -r kind a b; do
    case "$kind" in
      marketplace)
        if listed "$markets" "$a"; then say "ok       marketplace $a"
        else ensure "marketplace $a" claude plugin marketplace add "$b"; fi ;;
      plugin)
        if listed "$plugins" "$a"; then say "ok       plugin $a"
        else ensure "plugin $a" claude plugin install "$a"; fi ;;
      *) say "warn     claude/plugins.txt: unknown line '$kind $a $b'" ;;
    esac
  done < <(list_lines "$REPO/claude/plugins.txt")
}

# Print one line per server: name<TAB>server-json<TAB>command<US>arg<US>arg...
mcp_entries() {
  python3 - "$REPO/mcp/servers.json" <<'PY'
import json, sys
servers = json.load(open(sys.argv[1]))["mcpServers"]
for name, cfg in servers.items():
    cfg = dict(cfg)
    if "command" in cfg:
        cfg.setdefault("type", "stdio")
    cmd = "\x1f".join([cfg.get("command", "")] + cfg.get("args", []))
    print(f"{name}\t{json.dumps(cfg)}\t{cmd}")
PY
}

do_mcp() {
  if ! have python3; then say "skip     MCP servers (python3 not found)"; return 0; fi
  local name json cmdline cmd
  while IFS=$'\t' read -r name json cmdline; do
    if have claude; then
      if query claude mcp get "$name" >/dev/null 2>&1; then say "ok       claude mcp $name"
      else ensure "claude mcp $name" claude mcp add-json -s user "$name" "$json"; fi
    else
      say "skip     claude mcp $name (claude not found)"
    fi
    if have codex; then
      IFS=$'\x1f' read -ra cmd <<<"$cmdline"
      if query codex mcp get "$name" >/dev/null 2>&1; then say "ok       codex mcp $name"
      elif [[ -z "${cmd[0]:-}" ]]; then say "skip     codex mcp $name (no command; add url servers by hand)"
      else ensure "codex mcp $name" codex mcp add "$name" -- "${cmd[@]}"; fi
    else
      say "skip     codex mcp $name (codex not found)"
    fi
  done < <(mcp_entries)
}

do_links
if (( CHECK )); then
  exit "$NOT_OK"
fi
if (( ! LINKS_ONLY )); then
  do_skill_packs
  do_claude_plugins
  do_mcp
fi
say "done"
