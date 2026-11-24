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

say "==> install.sh sandbox test"
H="$(mktemp -d)"
trap 'rm -rf "$H"' EXIT
mkdir -p "$H/.gemini"
printf '# old\n' >"$H/.gemini/GEMINI.md"

before="$(find "$H" -printf '%p %l\n' | sort)"
HOME="$H" ./install.sh --dry-run --links-only >/dev/null
after="$(find "$H" -printf '%p %l\n' | sort)"
diff -u <(printf '%s\n' "$before") <(printf '%s\n' "$after")

HOME="$H" ./install.sh --links-only >/dev/null
[[ -d "$H/.agent-kit-backups" ]] || { echo "missing backup dir" >&2; exit 1; }

snap1="$(find "$H" -printf '%p %l\n' | sort)"
HOME="$H" ./install.sh --links-only >/dev/null
snap2="$(find "$H" -printf '%p %l\n' | sort)"
diff -u <(printf '%s\n' "$snap1") <(printf '%s\n' "$snap2")

HOME="$H" ./install.sh --check >/dev/null

say "==> init-project.sh & format-on-edit.sh smoke tests"
P="$(mktemp -d)"
touch "$P/CMakeLists.txt"
./scripts/init-project.sh "$P" >/dev/null
[[ -f "$P/AGENTS.md" && -f "$P/CLAUDE.md" ]] || { echo "init-project.sh failed" >&2; exit 1; }
grep -q "CMake" "$P/AGENTS.md" || { echo "init-project.sh missed CMake stack" >&2; exit 1; }
./hooks/format-on-edit.sh <<<'{"tool_input":{"file_path":""}}'
rm -rf "$P"

say "==> eval case structure"
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

say "ALL CHECKS PASSED"
