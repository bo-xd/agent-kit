# Hooks

Optional lifecycle scripts for **Claude Code** and **Antigravity**. They are not auto-linked into `settings.json` because `agent-kit` does not manage machine-specific settings files.

## Included

- `guard-command.sh` — pre-tool shell guard that blocks:
  - recursive `rm` on `/`, `~`, `$HOME`, or `..`
  - `git push --force` / `-f` to `main` or `master`
  - direct reads of `.ssh/id_*`, `.git-credentials`, `.gnupg/`, or `oauth_creds.json`

## Wire into Claude Code (`~/.claude/settings.json`)

Add under `"hooks"`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/home/bo/Coding/agent-kit/hooks/guard-command.sh"
          }
        ]
      }
    ]
  }
}
```

Test it locally before enabling:

```bash
echo '{"tool_input":{"command":"rm -rf ~"}}' | ./hooks/guard-command.sh   # exits 2
echo '{"tool_input":{"command":"ls -la"}}' | ./hooks/guard-command.sh     # exits 0
```
