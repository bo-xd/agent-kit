# Prompt Library

Copy-pasteable, high-leverage prompts tuned to Bo's stack. Pair any of these with the `prompt-sharpener` skill.

---

## 1. C/C++ UB, Memory & Leak Audit

```text
Audit <file-or-dir> for undefined behavior, memory safety bugs (use-after-free, out-of-bounds, uninitialized reads, leaks), integer overflow, and missing error checks.
Read the code and its callers first; do not edit yet.
Report findings as: `[severity] file:line — bug — trigger condition — minimal fix`.
```

## 2. Reverse Engineering / Decompilation Breakdown (Authorized Targets Only)

```text
Explain what this function / disassembly from <binary-or-crackme> does in plain terms.
Identify: inputs, state/structs, key branch conditions, crypto/encoding/hash constants, and any anti-debug or validation checks.
Do not guess — mark anything uncertain as `[unverified]` and suggest the exact gdb/r2/ltrace command to confirm it.
```

## 3. Quiz Me (Learning / School Mode)

```text
I want to understand <topic-or-file> deeply, not just get the answer.
Read <file> if needed, then quiz me one question at a time (starting from fundamentals and moving to edge cases).
Wait for my answer each turn, correct any gaps concisely, and only show code if I ask for a hint.
```

## 4. Cold Second-Opinion Diff Review (for Codex `/review` or a fresh session)

```text
Review `git diff` (or `git diff main...HEAD`) as a senior reviewer seeing this code cold.
Check for: correctness bugs, edge cases, hidden coupling, duplicated logic, and unverified assumptions.
Ignore formatting nitpicks. Output one bullet per real issue with `file:line`, impact, and minimal fix.
```

## 5. Session → Obsidian Note

```text
Use the `obsidian-vault` skill to save a concise postmortem/note of what we just solved into `~/Documents/Obsidian Vault/Hobby's/`.
Check `Sjablonen/` first for any matching template, search the vault so we don't duplicate an existing note, and keep it under 40 lines.
```
