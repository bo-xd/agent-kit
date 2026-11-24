---
name: prompt-sharpener
description: Rewrites rough or vague prompts into direct, structured prompts with clear goals, scope, constraints, and verification criteria. Use when the user asks to sharpen, rewrite, or improve a prompt, or gives an underspecified request before a major task.
---

# Prompt sharpener

Turn a rough idea into a prompt that gets the job done on the first pass, with no wasted exploration or guesswork.

## Two modes

1. **Rewrite-only (default when asked to "sharpen", "rewrite", or "improve" a prompt):**
   - Output the sharpened prompt inside a single fenced code block so it can be copied directly.
   - Below it, add at most 3 short bullets explaining what was added/tightened and why.
   - Do **not** execute the prompt unless asked.
2. **Sharpen-then-run (when the user wants the work done now, or says "sharpen and run"):**
   - State the sharpened 4-part spec (Objective, Context, Constraints, Done check) in 4–6 lines.
   - If a critical decision is still open, ask **one** short question; otherwise confirm you're proceeding with those defaults and execute.

## Anatomy of a sharp prompt

Every high-leverage engineering prompt answers four things—trim anything that doesn't serve one of them:

1. **Objective** — One concrete sentence: what changes or what output is produced.
2. **Context / Entry points** — Exact files, symbols, commands, or error output to read first (or "inspect X before editing").
3. **Constraints / Anti-goals** — What *not* to touch, dependency/style limits, performance or safety bounds.
4. **Done / Verification** — Exact command(s) or check(s) that prove it works (tests, build, `diff`, sandbox run).

## Rewrite checklist

- Replace vague verbs ("fix", "improve", "clean up", "make better") with observable outcomes ("make `ctest` pass", "reduce allocations in `render_frame`", "extract X into Y").
- Pin down scope ("only touch `src/lexer.*`", "keep public API unchanged").
- Add "plan first, don't edit yet" when the task spans >3 files or has design trade-offs.
- Strip filler ("please", "I feel like", "maybe")—directness saves tokens and sharpens attention.
- Never invent file paths or commands you haven't seen; use `<path/to/file>` placeholders if unknown.

## Examples (before → after)

**C/C++ bug:**
- *Before:* "my voxel engine crashes sometimes when loading chunks, can you fix it"
- *After:*
  ```text
  Find and fix the intermittent crash during chunk loading in src/world/chunk_loader.c.
  First build with `-fsanitize=address,undefined -g` and reproduce with `./build/voxel --headless --seed 42` (or inspect `load_chunk` + its callers if no headless flag exists).
  Constraints: smallest fix, no new dependencies, keep existing chunk file format.
  Done: ASan/UBSan run completes cleanly and existing tests pass. Show the exact commands and output.
  ```

**Feature / refactor:**
- *Before:* "refactor the parser it's messy"
- *After:*
  ```text
  Plan a refactor of src/parser.c to split expression parsing from statement parsing without changing any AST output or public headers.
  Read src/parser.c and tests/parser_test.c first, then propose a 3–5 step plan before editing.
  Constraints: no behavior changes, no new files unless clearly needed.
  Done: `make test` passes with zero new compiler warnings (`-Wall -Wextra`).
  ```
