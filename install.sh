#!/usr/bin/env bash
# Install Bo's AI setup: symlink rules, skills, agents and MCP config into every
# tool's config dir, then install third-party skills, Claude plugins and MCP
# servers via their CLIs. Idempotent. See README.md.
set -euo pipefail

if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ]]; then
  echo "error: native Windows symlinks are not supported; use WSL, Linux, or macOS" >&2
  exit 1
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)-$$"
BACKUP_DIR="$HOME/.agent-kit-backups/$TS"

DRY_RUN=0
CHECK=0
LINKS_ONLY=0
PRUNE_KEEP=""
NOT_OK=0
FAILED=0

usage() {
  cat <<EOF
Usage: ./install.sh [--dry-run] [--check] [--links-only] [--prune-backups N] [--help]

  (no flags)          create all links, then run the npx / claude / codex steps
  --dry-run           print every action, change nothing
  --check             verify links (and MCP/plugin state unless --links-only); exit 1 if any is not OK
  --links-only        only create links; skip the npx / claude / codex steps
  --prune-backups N   keep only the newest N directories in ~/.agent-kit-backups
  --help              show this help

Existing files or foreign symlinks at a target are moved to
~/.agent-kit-backups/<timestamp>/<same relative path> before linking.
EOF
}

while (( $# )); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --check) CHECK=1 ;;
    --links-only) LINKS_ONLY=1 ;;
    --prune-backups)
      shift
      [[ "${1:-}" =~ ^[0-9]+$ ]] || { echo "error: --prune-backups requires a non-negative integer" >&2; exit 2; }
      PRUNE_KEEP="$1" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
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

  local mcp_src="$REPO/mcp/servers.json"
  if have python3; then
    local mcp_resolved="$HOME/.cache/agent-kit/mcp_config.json"
    if (( ! CHECK )); then
      run mkdir -p "$(dirname "$mcp_resolved")"
      if (( DRY_RUN )); then
        say "[dry-run] render $REPO/mcp/servers.json -> $mcp_resolved"
      else
        render_mcp_json >"$mcp_resolved"
      fi
    fi
    mcp_src="$mcp_resolved"
  else
    say "warn     python3 not found; linking raw mcp/servers.json without \${VAR} expansion"
  fi
  link "$mcp_src" "$HOME/.gemini/config/mcp_config.json"
  link "$mcp_src" "$HOME/.cursor/mcp.json"
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

# Render mcp/servers.json (+ optional mcp/servers.local.json) with ${VAR} expanded.
# Refuses unset or empty ${VAR} placeholders so broken configs are never hashed.
render_mcp_json() {
  python3 - "$REPO/mcp/servers.json" "$REPO/mcp/servers.local.json" <<'PY'
import json, os, re, sys
VAR_RE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")
def expand(v):
    if isinstance(v, str):
        for name in VAR_RE.findall(v):
            if not os.environ.get(name):
                sys.stderr.write(f"error: MCP config references unset or empty env var '${{{name}}}'\n")
                sys.exit(1)
        return VAR_RE.sub(lambda m: os.environ[m.group(1)], v)
    if isinstance(v, list): return [expand(x) for x in v]
    if isinstance(v, dict): return {k: expand(val) for k, val in v.items()}
    return v
data = json.load(open(sys.argv[1]))
if os.path.exists(sys.argv[2]):
    data["mcpServers"].update(json.load(open(sys.argv[2])).get("mcpServers", {}))
print(json.dumps(expand(data), indent=2))
PY
}

# Print one line per server: name<TAB>hash<TAB>server-json<TAB>command<US>arg...<TAB>env<US>...<TAB>url<TAB>bearer_env<TAB>has_headers
mcp_entries() {
  render_mcp_json | python3 -c '
import hashlib, json, sys
servers = json.load(sys.stdin)["mcpServers"]
for name, cfg in servers.items():
    cfg = dict(cfg)
    if "command" in cfg:
        cfg.setdefault("type", "stdio")
    payload = json.dumps(cfg, sort_keys=True)
    digest = hashlib.sha256(payload.encode()).hexdigest()[:16]
    cmd = "\x1f".join([cfg.get("command", "")] + cfg.get("args", []))
    env_pairs = "\x1f".join(f"{k}={v}" for k, v in (cfg.get("env") or {}).items())
    url = cfg.get("url", "")
    bearer = cfg.get("bearer_token_env_var", "")
    has_hdrs = "1" if cfg.get("headers") else "0"
    print("\x1e".join([name, digest, payload, cmd, env_pairs, url, bearer, has_hdrs]))
'
}

do_mcp() {
  if ! have python3; then say "skip     MCP servers (python3 not found)"; return 0; fi
  local hash_dir="$HOME/.cache/agent-kit/mcp-hashes"
  local name digest json cmdline envline url bearer has_hdrs prev
  local -a cmd env_args url_args
  run mkdir -p "$hash_dir"
  while IFS=$'\x1e' read -r name digest json cmdline envline url bearer has_hdrs; do
    if have claude; then
      prev="$(cat "$hash_dir/claude-$name" 2>/dev/null || true)"
      if query claude mcp get "$name" >/dev/null 2>&1 && [[ "$prev" == "$digest" ]]; then
        say "ok       claude mcp $name"
      else
        if (( ! DRY_RUN )); then
          claude mcp remove -s user "$name" >/dev/null 2>&1 || true
        fi
        if ensure "claude mcp $name" claude mcp add-json -s user "$name" "$json"; then
          if (( ! DRY_RUN )); then printf '%s' "$digest" >"$hash_dir/claude-$name"; fi
        else
          echo "FAIL     claude mcp $name (hash not saved; rerun install.sh to retry)" >&2
          FAILED=1
        fi
      fi
    else
      say "skip     claude mcp $name (claude not found)"
    fi
    if have codex; then
      prev="$(cat "$hash_dir/codex-$name" 2>/dev/null || true)"
      IFS=$'\x1f' read -ra cmd <<<"$cmdline"
      env_args=()
      if [[ -n "$envline" ]]; then
        local -a env_items=()
        IFS=$'\x1f' read -ra env_items <<<"$envline"
        local kv
        for kv in "${env_items[@]}"; do env_args+=(--env "$kv"); done
      fi
      if query codex mcp get "$name" >/dev/null 2>&1 && [[ "$prev" == "$digest" ]]; then
        say "ok       codex mcp $name"
      elif [[ -n "${cmd[0]:-}" ]]; then
        if (( ! DRY_RUN )); then codex mcp remove "$name" >/dev/null 2>&1 || true; fi
        if ensure "codex mcp $name" codex mcp add "${env_args[@]}" "$name" -- "${cmd[@]}"; then
          if (( ! DRY_RUN )); then printf '%s' "$digest" >"$hash_dir/codex-$name"; fi
        else
          echo "FAIL     codex mcp $name (hash not saved; rerun install.sh to retry)" >&2
          FAILED=1
        fi
      elif [[ -n "$url" ]]; then
        if [[ "$has_hdrs" == "1" ]]; then
          say "warn     codex mcp $name: codex mcp add does not forward arbitrary HTTP headers (use bearer_token_env_var)"
        fi
        url_args=(--url "$url")
        [[ -n "$bearer" ]] && url_args+=(--bearer-token-env-var "$bearer")
        if (( ! DRY_RUN )); then codex mcp remove "$name" >/dev/null 2>&1 || true; fi
        if ensure "codex mcp $name" codex mcp add "${url_args[@]}" "$name"; then
          if (( ! DRY_RUN )); then printf '%s' "$digest" >"$hash_dir/codex-$name"; fi
        else
          echo "FAIL     codex mcp $name (hash not saved; rerun install.sh to retry)" >&2
          FAILED=1
        fi
      else
        say "skip     codex mcp $name (unsupported transport)"
      fi
    else
      say "skip     codex mcp $name (codex not found)"
    fi
  done < <(mcp_entries)
}

check_cli_layer() {
  if have claude; then
    local plugins kind a b
    plugins="$(claude plugin list 2>/dev/null || true)"
    while read -r kind a b; do
      [[ "$kind" == "plugin" ]] || continue
      if listed "$plugins" "$a"; then say "OK       plugin $a"
      else say "MISSING  plugin $a"; NOT_OK=1; fi
    done < <(list_lines "$REPO/claude/plugins.txt")
  fi
  if have python3; then
    local hash_dir="$HOME/.cache/agent-kit/mcp-hashes"
    local name digest _rest prev tool
    while IFS=$'\x1e' read -r name digest _rest; do
      for tool in claude codex; do
        have "$tool" || continue
        prev="$(cat "$hash_dir/$tool-$name" 2>/dev/null || true)"
        if [[ "$prev" == "$digest" ]]; then say "OK       $tool mcp $name"
        elif [[ -z "$prev" ]]; then say "MISSING  $tool mcp $name"; NOT_OK=1
        else say "STALE    $tool mcp $name"; NOT_OK=1; fi
      done
    done < <(mcp_entries)
  fi
}

prune_backups() {
  local keep="$1" root="$HOME/.agent-kit-backups"
  [[ -d "$root" ]] || return 0
  mapfile -t dirs < <(find "$root" -mindepth 1 -maxdepth 1 -type d | sort)
  local count="${#dirs[@]}"
  if (( count > keep )); then
    local i
    for (( i = 0; i < count - keep; i++ )); do
      say "prune    ${dirs[$i]}"
      run rm -rf "${dirs[$i]}"
    done
  fi
}

do_links
if (( CHECK )); then
  if (( ! LINKS_ONLY )); then
    check_cli_layer
  fi
  exit "$NOT_OK"
fi
if (( ! LINKS_ONLY )); then
  do_skill_packs
  do_claude_plugins
  do_mcp
fi
if [[ -n "$PRUNE_KEEP" ]]; then
  prune_backups "$PRUNE_KEEP"
fi
if (( FAILED )); then
  echo "install.sh finished with failures (see above)" >&2
  exit 1
fi
say "done"
