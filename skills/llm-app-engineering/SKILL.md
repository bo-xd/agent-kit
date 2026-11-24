---
name: llm-app-engineering
description: Engineering practices for building features and agents on top of LLM APIs in Python or TypeScript — structured output, tool use, evals, prompt versioning, cost and latency. Use when adding or changing an LLM call, prompt, RAG pipeline, or agent loop, when model output is flaky or unparseable, or when an LLM feature is too slow or expensive.
---

# LLM App Engineering

Treat the model as an unreliable, slow, metered dependency. Everything below follows
from that. For writing the surrounding code test-first, see **test-driven-development**.

## 1. Before writing a prompt

- [ ] Can this be done without an LLM (regex, parser, lookup, classic ML)? If yes, do that.
- [ ] Define the input and the **exact output shape** (schema) first.
- [ ] Collect 10–30 real example inputs with expected outputs → this is the first eval set.
- [ ] Pick the smallest model that passes the evals; upgrade only with evidence.

## 2. Structured output — never regex prose

Use the provider's native structured output / tool calling, and validate anyway.

```python
# Python: pydantic schema, validate, retry once with the error
from typing import Literal
from pydantic import BaseModel, ValidationError

class Ticket(BaseModel):
    category: Literal["bug", "feature", "question"]
    summary: str
    priority: int  # 1-3

def classify(text: str) -> Ticket:
    for attempt in range(2):
        raw = call_model(prompt=PROMPT_V3, input=text, response_schema=Ticket.model_json_schema())
        try:
            return Ticket.model_validate_json(raw)
        except ValidationError as e:
            text = f"{text}\n\nPrevious output was invalid: {e}. Return valid JSON only."
    raise LLMOutputError(raw)
```

TypeScript equivalent: `zod` schema + `schema.safeParse(JSON.parse(raw))`.
Always have a defined failure path (fallback value, error to user, human queue).

## 3. Prompts are code

- Store prompts in files (`prompts/classify.v3.md`) or constants with a version id, not
  inline f-strings scattered through the code.
- Log the prompt version, model id, and parameters with every call.
- Change a prompt → run the evals → compare against the previous version before merging.
- Keep instructions, examples, and untrusted input in clearly delimited sections
  (e.g. XML-style tags); put untrusted content last.

## 4. Evals

```
evals/
  cases.jsonl        # {"input": ..., "expected": ...}  (grow it from every production bug)
  run_evals.py       # runs all cases, prints pass rate + per-case diff, exits non-zero on regression
```

- Prefer **deterministic checks**: schema valid, field equals, contains/regex, numeric tolerance.
- Use LLM-as-judge only for fuzzy qualities, with a written rubric, and spot-check the judge.
- Track pass rate, cost, and p50/p95 latency per prompt/model version.
- Run evals in CI for prompt/model changes; set `temperature=0` (or fixed seed) where supported.

## 5. Tool use and agent loops

- Each tool: narrow purpose, typed parameters, clear description of *when* to use it,
  errors returned as text the model can act on.
- **Least privilege:** read-only by default; destructive actions (delete, pay, send, shell)
  need explicit confirmation or a dry-run mode.
- Hard limits: max iterations, max tokens, wall-clock timeout, per-run cost cap.
- Model output and tool results are **untrusted** (prompt injection from web pages, docs,
  emails). Never pipe them into `eval`, shell, SQL, or file paths unvalidated.
  See **security-review** for the full checklist.
- Log the full trajectory (messages, tool calls, results) for debugging.

## 6. RAG

- Evaluate retrieval separately from generation: for each eval question, is the right chunk in the top-k?
- Chunk by document structure (headings, functions), keep source ids, cite them in the answer.
- Filter by user/tenant **before** retrieval, not by asking the model to ignore data.

## 7. Cost and latency

- [ ] Measure tokens in/out per call (provider usage fields); estimate cost per request and per user/day.
- [ ] Put stable content (system prompt, tools, few-shot examples) first to hit prompt caching.
- [ ] Stream responses to the UI; parallelise independent calls; cache identical requests.
- [ ] Trim context: send only relevant chunks/history, summarise long conversations.
- [ ] Route easy cases to a small/fast model, hard ones to a large model — decided by evals.
- [ ] Timeouts + retries with exponential backoff and jitter on 429/5xx; idempotent retries only.

## 8. Operational checklist

- [ ] API keys from env/secret store, never in repo or client-side code.
- [ ] Model id pinned (dated version where offered), not a moving alias, for anything shipped.
- [ ] Graceful degradation when the provider is down or rate-limited.
- [ ] PII: know what you send to the provider; redact where required.
- [ ] Every production failure becomes a new eval case.
