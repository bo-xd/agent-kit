---
name: project-agents-md
description: Guide for writing or updating a project's AGENTS.md (read by Codex, Cursor, Antigravity, Junie, Copilot; Claude Code via a CLAUDE.md pointer) from the agent-kit template. Use when starting a new project, when an agent keeps making the same project-specific mistake, or when asked to create, improve, or audit an AGENTS.md / CLAUDE.md / GEMINI.md.
---

# Project AGENTS.md

An AGENTS.md tells any coding agent the **project-specific** facts it cannot guess:
how to build, test, and run, where things live, and the local rules. Global habits
(read before editing, smallest change, verify) already live in the global rules — do
not repeat them here.

Template: `templates/AGENTS.md` in the agent-kit repo
(`~/Coding/agent-kit/templates/AGENTS.md`).

## 1. Gather facts from the repo, don't invent them

```bash
git ls-files | head -100              # layout
ls; cat README* 2>/dev/null | head -80
cat CMakeLists.txt Makefile package.json pyproject.toml Cargo.toml 2>/dev/null | head -120
ls .github/workflows 2>/dev/null && cat .github/workflows/*.yml | head -80   # the real CI commands
cat .clang-format .editorconfig .eslintrc* ruff.toml 2>/dev/null | head -40
git log --oneline -15                 # commit message style
```

Every command you put in the file must be one you **ran successfully** (or is copied from
CI). If a command fails, fix it or leave it out and say so to the user.

## 2. Fill the template

Copy the template to the project root and fill each section. Delete sections that do not
apply rather than leaving placeholders. Aim for **30–80 lines**; agents read the whole file
every session, so every line costs tokens.

Good lines are specific and checkable:

- ✅ `Build: cmake -S . -B build -G Ninja && cmake --build build`
- ✅ `Never edit src/gen/*.c — regenerate with ./tools/gen_tables.py`
- ✅ `Kernel code is freestanding: no libc, no exceptions, no heap before mm_init()`
- ❌ `Write clean, maintainable code` (generic — belongs nowhere)
- ❌ `Be careful with memory` (not actionable)

## 3. Wire it up for every tool

```bash
# Claude Code reads CLAUDE.md, not AGENTS.md
printf '@AGENTS.md\n' > CLAUDE.md
# Antigravity/Gemini read GEMINI.md and AGENTS.md; only add GEMINI.md if tool-specific notes are needed.
```

Subdirectories with different rules (e.g. `kernel/`, `web/`) can have their own nested
AGENTS.md; keep the root one for project-wide facts.

## 4. Maintain it

- When an agent makes the same project-specific mistake twice, add **one line** that prevents it.
- When build/test commands change, update the file in the same change.
- Remove lines that are no longer true; stale instructions are worse than none.

## 5. Done checklist

- [ ] Build, test, and run commands were executed and work.
- [ ] Layout section names real directories.
- [ ] No generic advice, no secrets, no machine-specific absolute paths.
- [ ] No placeholder text (`<...>`, `TODO`) left from the template.
- [ ] `CLAUDE.md` pointer exists if the user uses Claude Code.
- [ ] Under ~80 lines.
