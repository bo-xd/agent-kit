---
name: reverse-engineering
description: Workflow for analysing compiled binaries with Ghidra, Binary Ninja, radare2, gdb, strace and ltrace, for authorized targets only (own binaries, crackmes, CTF challenges). Use when asked to understand, patch, or solve a binary, crackme, or CTF reversing/pwn challenge without source.
---

# Reverse Engineering

## Scope — authorized targets only

Use this skill only for binaries the user is allowed to analyse: **their own programs,
crackmes, CTF challenges, and deliberately vulnerable training targets.** Do not help
crack commercial software licences/DRM, bypass protections on software or services the
user doesn't own, or build malware. If the target's origin is unclear, ask before going
further. Run unknown binaries only in a VM/container (e.g. `docker run --rm -it
--network none -v "$PWD":/w archlinux`), never on the host.

## 1. Triage (2 minutes, no execution)

```bash
file ./target
sha256sum ./target
checksec --file=./target          # or: rabin2 -I ./target  (NX, PIE, canary, RELRO, stripped)
strings -n 6 ./target | less      # flags, prompts, error messages, URLs
rabin2 -zz ./target | grep -i -E 'flag|pass|key|correct|wrong'
readelf -h -S -d ./target         # arch, sections, needed libs
nm -C ./target | head             # symbols, if not stripped
objdump -d -M intel ./target | less
```

Note: architecture, static/dynamic, stripped or not, packer signs (`UPX!` in strings →
`upx -d` on a copy), language (Go/Rust/C++ symbol shapes).

## 2. Dynamic overview (in the sandbox)

```bash
strace -f -e trace=file,process,network ./target   # syscalls: files opened, execs, sockets
ltrace -S ./target                                  # libc calls: strcmp/memcmp often leak the check
LD_PRELOAD=./hook.so ./target                        # intercept a libc function you control
```

`ltrace` showing `strcmp("input", "s3cr3t")` solves many beginner crackmes; check it
before opening a disassembler.

## 3. Static analysis

- **Ghidra:** new project → import → auto-analyse. Start from `main` (or `entry` →
  `__libc_start_main` first arg when stripped), or from cross-refs to an interesting
  string (Search → For Strings → References). Rename and retype as you go; set function
  signatures so the decompiler output improves.
- **Binary Ninja:** use HLIL view; `Shift+X`/xrefs on strings; the Python console
  (`bv`, `current_function`) for scripting decoders.
- **radare2:**
  ```
  r2 -A ./target
  afl                 # functions
  iz                  # strings in data
  axt @ str.Correct   # xrefs to a string
  s main; pdf         # disassemble function
  VV                  # graph view
  ```

Work outward from the success/fail message to the comparison that decides it. Write down
each function's purpose in one line as you understand it.

## 4. Confirm with a debugger

```bash
gdb -q ./target        # pwndbg / gef make this much nicer if installed
```

```
starti                         # stop at first instruction (PIE: then 'info proc mappings')
break *0x401234                # break on an address (add PIE base when needed)
x/s $rdi  ;  x/16gx $rsp       # inspect args / stack
set $rax = 0                   # flip a check to test a hypothesis
```

Change one thing, observe, record. Breakpoints on `strcmp`/`memcmp`/`read` are a fast
way to find the input check.

## 5. Solving patterns

| Check shape | Approach |
|---|---|
| Plain compare to constant | Read the constant (strings / ltrace / gdb) |
| Input transformed then compared | Re-implement the transform in Python and invert it |
| Many arithmetic constraints | `z3` (`pip install z3-solver`) or `angr` symbolic execution |
| Keygen (name → serial) | Re-implement algorithm in Python; verify against binary |
| Anti-debug (`ptrace`, timing) | Patch the check on a copy, or `catch syscall ptrace` and fake return |
| Pwn: overflow | `cyclic` (pwntools) for offset; checksec decides ret2win/ROP/shellcode |

Patching: always on a copy (`cp target target.patched`); Ghidra/Binja patch-and-export or
`r2 -w`. Prefer solving (finding the input) over patching when the goal is a flag.

## 6. Output

- [ ] One-paragraph explanation of what the binary does and how the check works.
- [ ] The solution (input/flag/keygen script) and how it was verified against the binary.
- [ ] Solver scripts saved in the challenge directory, runnable (`python3 solve.py`).
- [ ] Note any tool/version assumptions (arch, libc version for pwn).
