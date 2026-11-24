# agent-kit

One source of truth for my AI coding setup across **Claude Code, Codex, Antigravity (`agy`), Cursor, and Junie**. Edit here, run `./install.sh`, and every tool stays in sync.

## Quick start (macOS / Linux / WSL)

```bash
git clone https://github.com/bo-xd/agent-kit.git ~/Coding/agent-kit
cd ~/Coding/agent-kit
./install.sh --dry-run   # preview without changing anything
./install.sh             # link files + sync skills, plugins, and MCPs
./install.sh --check     # verify links + MCP/plugin state
```

## Intentionally not managed

- Machine-specific settings (`~/.claude/settings.json`, `~/.codex/config.toml`)
- Secrets / API keys (use `${ENV_VAR}` placeholders + gitignored `mcp/servers.local.json`)
- Personal MCP servers (e.g. `whatsapp`)
- Per-project `AGENTS.md` (bootstrap with `./scripts/init-project.sh`)

## Per-harness setup

<details>
<summary><b>Claude Code</b> — rules, skills, plugins, MCPs, hooks</summary>

- **Rules:** `rules/global.md` → `~/.claude/CLAUDE.md`
- **Own skills:** `skills/*` → `~/.claude/skills/*`
- **Third-party packs:** installed as plugins via `claude/plugins.txt` (Claude does not read `~/.agents/skills`)
- **MCPs:** registered via `claude mcp add-json -s user` (re-synced automatically when config hashes change)
- **Hooks:** wire `hooks/guard-command.sh` + `hooks/format-on-edit.sh` manually into `~/.claude/settings.json` (see [hooks/README.md](hooks/README.md))

</details>

<details>
<summary><b>Antigravity (agy)</b> — rules, skills, subagents, MCPs</summary>

- **Rules:** `rules/global.md` → `~/.gemini/GEMINI.md`
- **Skills:** `skills/*` + `skills.txt` → `~/.agents/skills/*`
- **Subagents:** `agents/antigravity/*.md` → `~/.gemini/config/agents/*`
- **MCPs:** rendered config (`~/.cache/agent-kit/mcp_config.json`) → `~/.gemini/config/mcp_config.json`

</details>

<details>
<summary><b>Codex</b> — rules, skills, MCPs</summary>

- **Rules:** `rules/global.md` → `~/.codex/AGENTS.md`
- **Skills:** `skills/*` + `skills.txt` → `~/.agents/skills/*`
- **MCPs:** registered via `codex mcp add` (forwards `--env` for stdio and `--bearer-token-env-var` for URL servers)

</details>

<details>
<summary><b>Cursor &amp; Junie</b> — skills, MCPs</summary>

- **Skills:** `skills/*` + `skills.txt` → `~/.agents/skills/*`
- **Cursor MCPs:** rendered config (`~/.cache/agent-kit/mcp_config.json`) → `~/.cursor/mcp.json`

</details>

## Reference

<details>
<summary><b>Installer flags &amp; helper scripts</b></summary>

| Command / Flag | What it does |
|---|---|
| `./install.sh --dry-run` | Print actions, change nothing |
| `./install.sh --links-only` | Symlinks only (offline-safe, skips `npx`/`claude`/`codex`) |
| `./install.sh --check` | Verify links + MCP/plugin state (pair with `--links-only` for links only) |
| `./install.sh --prune-backups N` | Keep only the newest `N` folders in `~/.agent-kit-backups` |
| `./scripts/sync.sh` | Pull, re-link, update third-party packs, and `--check` |
| `./scripts/init-project.sh [--verify]` | Bootstrap `AGENTS.md` + `CLAUDE.md` in any repo |
| `./scripts/eval.sh` | Run multi-agent A/B benchmarks (`agy`, `codex`, `claude`) |
| `./scripts/verify.sh` | Run syntax, skill, hook, and sandbox install tests |

</details>

<details>
<summary><b>Repo layout &amp; adding things</b></summary>

- `rules/global.md` — shared rules for every agent
- `skills/<name>/SKILL.md` — custom skills (auto-linked into `~/.agents/skills` and `~/.claude/skills`; see [docs/WORKFLOW.md](docs/WORKFLOW.md))
- `skills.txt` / `claude/plugins.txt` — third-party skill packs & Claude plugins
- `mcp/servers.json` — shared MCP servers (`mcp/servers.local.json` for local overrides)
- `hooks/`, `prompts/`, `templates/AGENTS.md`, `evals/`

</details>

<details>
<summary><b>Backups &amp; undo</b></summary>

Replaced files/symlinks are **moved** (never deleted) to `~/.agent-kit-backups/<timestamp>/`. To restore a target:

```bash
rm ~/.claude/CLAUDE.md
mv ~/.agent-kit-backups/<timestamp>/.claude/CLAUDE.md ~/.claude/
```

</details>
