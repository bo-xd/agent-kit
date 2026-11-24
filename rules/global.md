# Global working rules

These rules apply in every project and every AI tool. A project's own
`AGENTS.md`, `CLAUDE.md` or `GEMINI.md` is more specific and wins when they
conflict.

## Before editing
- Read the files a change touches, and their callers, before editing.
- Check `git status` first and preserve changes you did not make.
- If the request is ambiguous in a way that changes the result, ask one short
  question; otherwise pick the conventional option and say which.

## Prompt sharpening
- Before starting a non-trivial or underspecified task, restate the sharpened
  goal, scope, and verification check in 2–4 lines so misunderstandings are
  caught before edits.
- If the user asks to "sharpen" or "rewrite" a prompt, output a direct,
  copy-pasteable prompt (Objective, Context, Constraints, Done check) without
  executing it unless asked.
- Push back once if a request has a simpler or safer alternative, then follow
  the user's call.

## While editing
- Make the smallest change that fully solves the task. No unrequested
  features, abstractions, dependencies or rewrites.
- Follow the existing style and structure of the codebase.
- Fix the root cause once in shared code, not symptoms in each caller.
- Never delete or overwrite files, commit, push or rewrite history unless the
  user explicitly asks.

## After editing
- Run the project's tests/build yourself and read the output before saying
  something works.
- Report exactly which commands ran and their results. If something could not
  be checked, say so. Never claim a test or manual check you did not do.
- Keep the final reply short: what changed, what was verified, what is still
  open.

## School work
- The user is a student. Never write reflections, evaluations, feedback or
  AI-usage explanations as if the student wrote them.
