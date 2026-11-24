---
name: security-review
description: Checklist-driven security review of the user's own code (C/C++, web backends, Python/TypeScript, LLM features). Use when asked for a security review or audit, before shipping code that handles untrusted input, auth, secrets, files, or network data, or when a diff touches parsing, memory management, SQL/shell, or permissions.
---

# Security Review

For reviewing **code the user owns or is authorized to assess**. Testing live third-party
systems is out of scope unless the user states they have permission (e.g. a bug bounty
scope or a lab like DVWA/Juice Shop). For general code-review mechanics use
**requesting-code-review** / **receiving-code-review**; this skill is the security lens.

## 1. Map the attack surface first

Write down, before reading code line by line:

- **Entry points:** CLI args, files parsed, network sockets/HTTP routes, env vars, IPC,
  plugin/script loading, LLM output fed back into tools.
- **Trust boundaries:** where untrusted data becomes trusted (after validation? never?).
- **Assets:** secrets, user data, privileged operations, memory-safety of a long-running process.

Review the code on those paths first; everything else is secondary.

## 2. Automated pass (cheap, run before manual review)

```bash
# Secrets in tree / history
git ls-files | xargs grep -nE '(api[_-]?key|secret|passw(or)?d|token|BEGIN (RSA|OPENSSH) PRIVATE)' -i
gitleaks detect --source . 2>/dev/null || true

# C/C++
cmake -S . -B build-san -DCMAKE_C_FLAGS="-fsanitize=address,undefined -g" -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -g"
clang-tidy -p build-san $(git ls-files '*.c' '*.cpp') -checks='clang-analyzer-*,bugprone-*,cert-*'
scan-build make                         # clang static analyzer
cppcheck --enable=warning,portability --inconclusive .

# Python / JS / TS
uvx semgrep --config auto .             # multi-language rules
uvx bandit -r src/                      # Python
uvx pip-audit                           # Python deps
npm audit --omit=dev                    # Node deps
```

Treat tool output as leads, not verdicts: confirm each finding by reading the code path.

## 3. Manual checklist by category

**Memory safety (C/C++)**
- [ ] Every buffer write bounded by the *destination* size; no `strcpy/sprintf/gets`.
- [ ] Integer overflow before `malloc(n * size)` / index math; signed/unsigned mixing.
- [ ] Lifetimes: no use-after-free, double free, dangling refs/iterators, returned stack pointers.
- [ ] Format strings are literals (`printf(user)` is a bug).
- [ ] Parsers (lexers, file loaders, network packets) handle truncated/hostile input; fuzz
      them: `clang -fsanitize=fuzzer,address` with a `LLVMFuzzerTestOneInput` harness.

**Injection**
- [ ] SQL uses parameterised queries only.
- [ ] No shell with interpolated input (`system`, `popen`, `subprocess(..., shell=True)`,
      `child_process.exec`); use argv arrays.
- [ ] HTML output escaped by the template engine; no `innerHTML`/`dangerouslySetInnerHTML` with user data.
- [ ] Path inputs normalised and confined (`realpath` + prefix check); no `../` traversal.
- [ ] No deserialisation of untrusted data with `pickle`, `yaml.load`, Java/PHP native serialisers.

**AuthN / AuthZ / sessions (web)**
- [ ] Every route checks authorization server-side, per object (IDOR).
- [ ] Passwords hashed with argon2/bcrypt/scrypt; constant-time compares for tokens.
- [ ] Cookies `HttpOnly; Secure; SameSite`; CSRF protection on state-changing requests.
- [ ] CORS not `*` with credentials; SSRF: outbound fetches of user URLs are allow-listed.

**Secrets & config**
- [ ] No secrets in repo, logs, error messages or client bundles; loaded from env/secret store.
- [ ] Debug endpoints/flags off in production builds.

**LLM features** (see also **llm-app-engineering**)
- [ ] Model output treated as untrusted input: never passed straight to shell, SQL, eval, or file paths.
- [ ] Prompt injection via retrieved docs/web pages/tool results considered; tools are least-privilege.
- [ ] Destructive tool calls require confirmation; per-user data isolation in RAG.

## 4. Verify with Burp / ZAP (own app, local)

Run the app locally, proxy the browser through Burp or ZAP, and replay requests with
tampered IDs, roles, and payloads for each finding you suspect. A finding is confirmed
when you can reproduce it, not when it "looks wrong".

## 5. Report format

One entry per finding, highest severity first:

```
[HIGH] src/net/packet.c:88 — length field trusted before memcpy → heap overflow
  Repro: send packet with len=0xffff (poc/overflow.py)
  Fix:   check len <= sizeof(buf) - off before copying; add fuzz harness
```

Severity: **Critical** (RCE, auth bypass, secret leak) · **High** (memory corruption,
injection, IDOR) · **Medium** (needs unusual conditions) · **Low/Info** (hardening).
State explicitly what was *not* reviewed.
