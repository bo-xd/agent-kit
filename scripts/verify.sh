#!/usr/bin/env bash
# Self-verification suite for agent-kit: syntax, JSON, hook tests, skill
# frontmatter checks, and sandboxed install.sh idempotency + --check.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

say() { printf '%s\n' "$*"; }

say "==> bash syntax"
bash -n install.sh hooks/guard-command.sh hooks/format-on-edit.sh scripts/verify.sh scripts/init-project.sh scripts/sync.sh scripts/eval.sh

if command -v shellcheck >/dev/null 2>&1; then
  say "==> shellcheck"
  shellcheck install.sh hooks/guard-command.sh hooks/format-on-edit.sh scripts/verify.sh scripts/init-project.sh scripts/sync.sh scripts/eval.sh
else
  say "==> shellcheck (skipped: not installed)"
fi

say "==> JSON validation"
python3 -m json.tool mcp/servers.json >/dev/null
python3 -m json.tool .claude-plugin/plugin.json >/dev/null

if command -v claude >/dev/null 2>&1; then
  say "==> claude plugin validate"
  claude plugin validate . >/dev/null
fi

say "==> SKILL.md frontmatter & size"
python3 - <<'PY'
import glob, os, re, sys

skills = sorted(glob.glob("skills/*/SKILL.md"))
if not skills:
    sys.exit("no skills found")

errors = []
for path in skills:
    dirname = os.path.basename(os.path.dirname(path))
    text = open(path, encoding="utf-8").read()
    lines = text.splitlines()
    if len(lines) > 150:
        errors.append(f"{path}: {len(lines)} lines (limit 150)")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        errors.append(f"{path}: missing YAML frontmatter")
        continue
    fm = m.group(1)
    name_m = re.search(r"^name:\s*(\S+)\s*$", fm, re.M)
    desc_m = re.search(r"^description:\s*(.+)$", fm, re.M)
    if not name_m or name_m.group(1) != dirname:
        errors.append(f"{path}: frontmatter name != '{dirname}'")
    if not desc_m or "use when" not in desc_m.group(1).lower():
        errors.append(f"{path}: description should include 'Use when ...'")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"OK: {len(skills)} skills validated")
PY

say "==> guard-command.sh smoke tests"
expect_block() {
  local rc=0
  ./hooks/guard-command.sh >/dev/null 2>&1 <<<"$1" || rc=$?
  [[ "$rc" -eq 2 ]] || { echo "expected exit 2, got $rc for: $1" >&2; exit 1; }
}
expect_block '{"tool_input":{"command":"rm -rf ~"}}'
expect_block '{"tool_input":{"command":"git push --force origin main"}}'
expect_block '{"tool_input":{"command":"cat ~/.ssh/id_ed25519"}}'
./hooks/guard-command.sh >/dev/null 2>&1 <<<'{"tool_input":{"command":"ls -la"}}'

say "==> install.sh sandbox matrix (fresh, existing, broken, upgrade)"
# 1. Fresh install
H_FRESH="$(mktemp -d)"
HOME="$H_FRESH" ./install.sh --links-only >/dev/null
HOME="$H_FRESH" ./install.sh --check >/dev/null
rm -rf "$H_FRESH"

# 2. Existing files + foreign/dangling symlinks + idempotency
H="$(mktemp -d)"
trap 'rm -rf "$H"' EXIT
mkdir -p "$H/.gemini" "$H/.claude" "$H/.codex"
printf '# old\n' >"$H/.gemini/GEMINI.md"
ln -s /nonexistent/dangling "$H/.claude/CLAUDE.md"
ln -s /tmp "$H/.codex/AGENTS.md"

before="$(find "$H" -printf '%p %l\n' | sort)"
HOME="$H" ./install.sh --dry-run --links-only >/dev/null
after="$(find "$H" -printf '%p %l\n' | sort)"
diff -u <(printf '%s\n' "$before") <(printf '%s\n' "$after")

if HOME="$H" ./install.sh --check >/dev/null 2>&1; then
  echo "expected --check to fail on broken links" >&2; exit 1
fi

HOME="$H" ./install.sh --links-only >/dev/null
[[ -d "$H/.agent-kit-backups" ]] || { echo "missing backup dir" >&2; exit 1; }
grep -q '# old' "$H"/.agent-kit-backups/*/.gemini/GEMINI.md

snap1="$(find "$H" -printf '%p %l\n' | sort)"
HOME="$H" ./install.sh --links-only >/dev/null
snap2="$(find "$H" -printf '%p %l\n' | sort)"
diff -u <(printf '%s\n' "$snap1") <(printf '%s\n' "$snap2")

HOME="$H" ./install.sh --check >/dev/null

# 3. Upgrade / MCP reconciliation with mock claude & codex CLIs
MOCK_BIN="$(mktemp -d)"
MCP_LOG="$H/mcp.log"
cat >"$MOCK_BIN/claude" <<'SH'
#!/usr/bin/env bash
echo "claude $*" >>"$MCP_LOG"
case "$1 $2" in
  "mcp get") grep -q "^installed $3$" "$MCP_STATE" 2>/dev/null ;;
  "mcp add-json") echo "installed $5" >>"$MCP_STATE" ;;
  "mcp remove") sed -i "/^installed $5$/d" "$MCP_STATE" 2>/dev/null || true ;;
  "plugin marketplace"|"plugin list") exit 0 ;;
esac
SH
cat >"$MOCK_BIN/codex" <<'SH'
#!/usr/bin/env bash
echo "codex $*" >>"$MCP_LOG"
case "$1 $2" in
  "mcp get") grep -q "^codex $3$" "$MCP_STATE" 2>/dev/null ;;
  "mcp add") echo "codex $3" >>"$MCP_STATE" ;;
  "mcp remove") sed -i "/^codex $3$/d" "$MCP_STATE" 2>/dev/null || true ;;
esac
SH
chmod +x "$MOCK_BIN/claude" "$MOCK_BIN/codex"
printf '#!/usr/bin/env bash\nexit 0\n' >"$MOCK_BIN/npx"
chmod +x "$MOCK_BIN/npx"

# Run with mock CLIs (npx skipped via PATH containing only basic utils + MOCK_BIN)
export MCP_LOG MCP_STATE="$H/mcp.state"
PATH="$MOCK_BIN:/usr/bin:/bin" HOME="$H" ./install.sh >/dev/null 2>&1 || true
grep -q "claude mcp add-json -s user context7" "$MCP_LOG"
grep -q "codex mcp add context7" "$MCP_LOG"

# Re-run unchanged -> must NOT re-add MCP servers
: >"$MCP_LOG"
PATH="$MOCK_BIN:/usr/bin:/bin" HOME="$H" ./install.sh >/dev/null 2>&1 || true
if grep -q "mcp add" "$MCP_LOG"; then
  echo "expected no MCP re-add on unchanged upgrade" >&2; exit 1
fi

# Simulate config change by changing cached hash -> must remove + re-add
printf 'stale-hash' >"$H/.cache/agent-kit/mcp-hashes/claude-context7"
: >"$MCP_LOG"
PATH="$MOCK_BIN:/usr/bin:/bin" HOME="$H" ./install.sh >/dev/null 2>&1 || true
grep -q "claude mcp remove -s user context7" "$MCP_LOG"
grep -q "claude mcp add-json -s user context7" "$MCP_LOG"

# 4. Recovery from failed MCP registration: hash must NOT be saved, rerun recovers
cat >"$MOCK_BIN/claude" <<'SH'
#!/usr/bin/env bash
echo "claude $*" >>"$MCP_LOG"
case "$1 $2" in
  "mcp get") grep -q "^installed $3$" "$MCP_STATE" 2>/dev/null ;;
  "mcp add-json") exit 1 ;;
  "mcp remove") sed -i "/^installed $5$/d" "$MCP_STATE" 2>/dev/null || true ;;
  "plugin marketplace"|"plugin list") exit 0 ;;
esac
SH
chmod +x "$MOCK_BIN/claude"
rm -f "$H/.cache/agent-kit/mcp-hashes/claude-context7"
: >"$MCP_LOG"
if PATH="$MOCK_BIN:/usr/bin:/bin" HOME="$H" ./install.sh >/dev/null 2>&1; then
  echo "expected install.sh to exit non-zero on MCP failure" >&2; exit 1
fi
[[ ! -f "$H/.cache/agent-kit/mcp-hashes/claude-context7" ]] || { echo "hash saved despite failure" >&2; exit 1; }
rm -rf "$MOCK_BIN"

say "==> init-project.sh & format-on-edit.sh smoke tests"
P="$(mktemp -d)"
touch "$P/CMakeLists.txt"
./scripts/init-project.sh "$P" >/dev/null
[[ -f "$P/AGENTS.md" && -f "$P/CLAUDE.md" ]] || { echo "init-project.sh failed" >&2; exit 1; }
grep -q "CMake" "$P/AGENTS.md" || { echo "init-project.sh missed CMake stack" >&2; exit 1; }
./hooks/format-on-edit.sh <<<'{"tool_input":{"file_path":""}}'
rm -rf "$P"

say "==> eval case structure & scaffold baseline repro"
python3 - <<'PY'
import glob, re, sys
cases = sorted(glob.glob("evals/*/*/case.yaml"))
if not cases:
    sys.exit("no eval cases found")
for path in cases:
    text = open(path, encoding="utf-8").read()
    for key in ("name:", "prompt:", "assertions:"):
        if not re.search(rf"^{key}", text, re.M):
            sys.exit(f"{path}: missing '{key}'")
print(f"OK: {len(cases)} eval cases validated")
PY

if command -v gcc >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
  if make -C evals/c-cpp-debugging/uaf-in-parser/scaffold test >/dev/null 2>&1; then
    echo "expected uaf-in-parser scaffold baseline to fail under ASan" >&2
    make -C evals/c-cpp-debugging/uaf-in-parser/scaffold clean >/dev/null 2>&1 || true
    exit 1
  fi
  make -C evals/c-cpp-debugging/uaf-in-parser/scaffold clean >/dev/null 2>&1 || true
fi

say "ALL CHECKS PASSED"
