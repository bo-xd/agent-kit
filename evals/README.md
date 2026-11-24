# Evals

Starter evaluation cases for `agent-kit` skills so prompt/skill edits can be tested against concrete expectations rather than guesswork.

## Running with Claude Code

```bash
./scripts/eval.sh
# or filter to a specific case:
./scripts/eval.sh --case intermittent
```

## Adding a case

Create `evals/<skill>/<case-name>/case.yaml` with:
- `prompt`: realistic user request
- `assertions`: observable behaviors the response must satisfy (tools/commands mentioned, constraints respected, no fabricated outputs)
