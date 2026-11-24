# AGENTS.md — editing this repo

This repo is the single source of truth for Bo's AI coding setup. `install.sh`
symlinks its files into each tool's config dir, so **editing a file here
changes the live config of every tool at once**.

## Layout
| Path | What | Linked / installed to |
|---|---|---|
| `rules/global.md` | global rules for all tools | `~/.gemini/GEMINI.md`, `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` |
| `skills/<name>/SKILL.md` | Bo's own skills | `~/.agents/skills/<name>`, `~/.claude/skills/<name>` |
| `agents/antigravity/*.md` | Antigravity subagents | `~/.gemini/config/agents/` |
| `mcp/servers.json` | shared MCP servers (`{"mcpServers":{...}}`) | Antigravity + Cursor (linked), Claude + Codex (via CLI) |
| `skills.txt` | third-party skill packs | `npx -y skills add <line> -g -y` |
| `claude/plugins.txt` | Claude marketplaces + plugins | `claude plugin marketplace add` / `claude plugin install` |
| `hooks/` | optional Claude/agy safety & format hooks | not auto-linked (`hooks/README.md`) |
| `prompts/` | reusable high-leverage prompt library | not linked |
| `evals/` | starter skill eval cases | not linked |
| `scripts/` | `verify.sh`, `init-project.sh`, `sync.sh` | not linked |
| `templates/AGENTS.md` | per-project AGENTS.md template | not linked |

## Rules
- Never run `./install.sh` against the real `$HOME` to test. Use a sandbox:
  `HOME=$(mktemp -d) ./install.sh --links-only`, then `--check`.
- Keep `install.sh` idempotent: a second run must change nothing. It must back
  up (never delete) anything it replaces.
- No secrets, tokens or personal MCP servers (e.g. whatsapp) in this repo.
- Do not manage machine-specific settings files (`settings.json`, `config.toml`).
- New skill: `skills/<name>/SKILL.md` with frontmatter `name` (== dir name) and
  a third-person `description` that says when to use it. `install.sh` picks up
  every dir under `skills/` automatically.
- Keep `rules/global.md` tool-neutral; it is read by Claude, Codex and Antigravity.

## Verify after changes
```bash
./scripts/verify.sh
```
