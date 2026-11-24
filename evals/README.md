# Evals

Evaluation cases for `agent-kit` skills.

## Automated vs. Human-Reviewed Checks

- **Automated (`./scripts/verify.sh`):** validates skill frontmatter, `case.yaml` structure, and verifies runnable eval scaffolds reproduce their baseline failure cleanly (e.g. `uaf-in-parser` triggers ASan before a fix).
- **Live LLM evals (`./scripts/eval.sh`):** runs `claude plugin eval` with `--ablation with-without` (baseline vs. skill), reporting score delta, tool calls, token usage, and execution time. Assertions in `case.yaml` are graded by the eval runner and should be spot-checked by a human when changing skills.

## Running with Claude Code

```bash
./scripts/eval.sh
# or filter to a specific case:
./scripts/eval.sh --case uaf-in-parser
```

## Reproducible A/B Benchmark (`scripts/bench.py`)

Runs isolated workspaces across 3 conditions (`baseline`, `agent-kit`, `agent-kit+skill`) for `claude`, `codex`, and `agy`, then restores immutable `oracle/` tests before running `verify_cmd` so agents cannot weaken tests:

```bash
./scripts/bench.py --dry-run
./scripts/bench.py --agents claude codex agy --task uaf-debug
```

## Adding a case

Create `evals/<skill>/<case-name>/case.yaml` (and an optional `scaffold/` directory for runnable code tasks) with:
- `name`: case identifier
- `prompt`: realistic user task
- `assertions`: observable correctness checks (avoid rewarding mere keyword mentions)
