---
name: obsidian-vault
description: Reads, searches, and writes notes in Bo's Obsidian vault (~/Documents/Obsidian Vault) using its folder structure, templates, and wikilinks. Use when saving debugging postmortems, CTF/crackme writeups, architecture notes, or looking up/organizing existing vault notes.
---

# Obsidian vault

Vault root: `~/Documents/Obsidian Vault` (also exposed via the `obsidian-vault` MCP server when enabled).

## Layout & boundaries

- `Sjablonen/` — existing note templates. Check here before creating a new note type so frontmatter and headings match.
- `Hobby's/` — personal projects, C/C++ notes, reverse-engineering/CTF writeups, experiments.
- `Stage/` and `feedback/` — internship & school notes.
  - **Hard rule:** never write reflections, self-evaluations, feedback responses, or AI-usage statements as if Bo wrote them. You may only organize, format, or summarize notes Bo already wrote.
- `Home.md`, `Over mij` — personal index/bio; do not overwrite without explicit instruction.

## Note conventions

- **Atomic notes:** one topic per note, clear `# Title`, concise sections, code blocks with language tags (`c`, `cpp`, `bash`, `asm`).
- **Wikilinks:** link related concepts with `[[Note Name]]` or `[[Folder/Note Name|Alias]]` instead of duplicating explanations.
- **Frontmatter:** keep YAML minimal (`tags: [...]`, `created: YYYY-MM-DD`). Match `Sjablonen/` if a template exists.
- **Search before creating:** check existing notes first (`rg` or MCP `search_files`) so you update or link rather than creating duplicates.

## "Session → Note" workflow

At the end of a non-trivial debugging session, kernel/compiler deep dive, or crackme/CTF solve, offer to save a short note:

```markdown
---
tags: [debugging, c]
created: YYYY-MM-DD
---
# <Short problem title>

## Symptom
What failed and the exact error/crash.

## Root cause
Why it happened (file/symbol/invariant).

## Fix & verification
What changed and the command that proved it.

## Related
- [[...]]
```

Keep notes tight and factual — write for future-Bo skimming in 30 seconds.
