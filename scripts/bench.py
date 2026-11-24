#!/usr/bin/env python3
"""Reproducible benchmark runner for agent-kit.

Compares agents (claude, codex, agy) across 3 conditions:
  1. baseline         - no agent-kit rules or skills
  2. agent-kit        - rules/global.md only
  3. agent-kit+skill  - rules/global.md + task's relevant SKILL.md

Each run gets an isolated workspace and an isolated HOME. After the agent
finishes, immutable oracle test files are restored before running verify_cmd so
agents cannot weaken tests or criteria.
"""
import argparse, json, os, shutil, subprocess, sys, tempfile, time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BENCH_DIR = REPO / "evals" / "bench"
RESULTS_DIR = REPO / "evals" / "results"


def load_tasks(task_filter: str | None):
    tasks = []
    for p in sorted(BENCH_DIR.glob("*/task.json")):
        data = json.loads(p.read_text(encoding="utf-8"))
        data["_dir"] = p.parent
        if not task_filter or task_filter in data["name"]:
            tasks.append(data)
    return tasks


def build_env(home: Path, condition: str, skill_name: str | None) -> dict[str, str]:
    real_home = Path.home()
    env = os.environ.copy()
    env["HOME"] = str(home)
    # Link auth files only (never rules/skills) so CLIs can authenticate in baseline.
    auth_files = [
        ".codex/auth.json",
        ".gemini/oauth_creds.json",
        ".gemini/google_accounts.json",
        ".gemini/installation_id",
        ".claude/.credentials.json",
        ".claude.json",
    ]
    for rel in auth_files:
        src = real_home / rel
        if src.exists():
            dst = home / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.symlink_to(src)

    rules = (REPO / "rules" / "global.md").read_text(encoding="utf-8")
    skill_txt = ""
    if condition == "agent-kit+skill" and skill_name:
        sp = REPO / "skills" / skill_name / "SKILL.md"
        if sp.exists():
            skill_txt = "\n\n" + sp.read_text(encoding="utf-8")

    if condition in ("agent-kit", "agent-kit+skill"):
        for sub, fname in [(".claude", "CLAUDE.md"), (".codex", "AGENTS.md"), (".gemini", "GEMINI.md")]:
            d = home / sub
            d.mkdir(parents=True, exist_ok=True)
            (d / fname).write_text(rules + skill_txt, encoding="utf-8")
        if skill_txt and skill_name:
            for root in (home / ".agents" / "skills" / skill_name, home / ".claude" / "skills" / skill_name):
                root.mkdir(parents=True, exist_ok=True)
                shutil.copy2(REPO / "skills" / skill_name / "SKILL.md", root / "SKILL.md")
    return env


def run_agent(agent: str, prompt: str, workdir: Path, env: dict[str, str], timeout: int) -> dict:
    t0 = time.monotonic()
    cmd = {
        "claude": ["claude", "-p", "--output-format", "json", "--dangerously-skip-permissions", "--no-session-persistence", prompt],
        "codex": ["codex", "exec", "--json", "--dangerously-bypass-approvals-and-sandbox", "--skip-git-repo-check", "-C", str(workdir), prompt],
        "agy": ["agy", f"-p={prompt}", "--output-format", "json", "--dangerously-skip-permissions", "--disable-slash-commands", "--model", "gemini-4-hydrogen-medium"],
    }[agent]
    try:
        proc = subprocess.run(cmd, cwd=workdir, env=env, capture_output=True, text=True, timeout=timeout)
        elapsed = round(time.monotonic() - t0, 2)
        tokens, tool_calls = parse_metrics(agent, proc.stdout)
        return {"exit_code": proc.returncode, "elapsed_s": elapsed, "tokens": tokens, "tool_calls": tool_calls, "timed_out": False}
    except subprocess.TimeoutExpired:
        return {"exit_code": -1, "elapsed_s": round(time.monotonic() - t0, 2), "tokens": None, "tool_calls": None, "timed_out": True}


def parse_metrics(agent: str, stdout: str):
    tokens, tool_calls = None, None
    try:
        if agent == "claude":
            data = json.loads(stdout)
            u = data.get("usage") or {}
            if u:
                tokens = sum(u.get(k, 0) for k in ("input_tokens", "output_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
            tool_calls = data.get("num_turns")
        elif agent == "codex":
            tc = 0
            tok = 0
            for line in stdout.splitlines():
                if not line.strip().startswith("{"):
                    continue
                ev = json.loads(line)
                if ev.get("type") == "item.completed" and (ev.get("item") or {}).get("type") == "command_execution":
                    tc += 1
                u = ev.get("usage") or {}
                if u:
                    tok += u.get("input_tokens", 0) + u.get("output_tokens", 0)
            tool_calls = tc or None
            tokens = tok or None
    except Exception:
        pass
    return tokens, tool_calls


def verify_workspace(task: dict, workdir: Path) -> bool:
    oracle = task["_dir"] / "oracle"
    if oracle.exists():
        for f in oracle.iterdir():
            shutil.copy2(f, workdir / f.name)
    res = subprocess.run(task["verify_cmd"], shell=True, cwd=workdir, capture_output=True, text=True, timeout=60)
    return res.returncode == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--agents", nargs="+", default=["claude"], choices=["claude", "codex", "agy"])
    ap.add_argument("--conditions", nargs="+", default=["baseline", "agent-kit", "agent-kit+skill"])
    ap.add_argument("--task", default=None)
    ap.add_argument("--timeout", type=int, default=180)
    ap.add_argument("--dry-run", action="store_true", help="Verify oracle workspaces without calling agents")
    args = ap.parse_args()

    tasks = load_tasks(args.task)
    if not tasks:
        sys.exit("no matching benchmark tasks found")

    if args.dry_run:
        for t in tasks:
            with tempfile.TemporaryDirectory() as td:
                wd = Path(td) / "work"
                shutil.copytree(t["_dir"] / "workspace", wd)
                passed = verify_workspace(t, wd)
                print(f"dry-run {t['name']:18s} baseline_oracle_passes={passed}")
        return

    results = []
    for t in tasks:
        for agent in args.agents:
            if not shutil.which(agent):
                print(f"skip {agent} (not installed)")
                continue
            for cond in args.conditions:
                with tempfile.TemporaryDirectory() as td:
                    td_path = Path(td)
                    wd = td_path / "work"
                    home = td_path / "home"
                    home.mkdir()
                    shutil.copytree(t["_dir"] / "workspace", wd)
                    env = build_env(home, cond, t.get("skill"))
                    run_info = run_agent(agent, t["prompt"], wd, env, args.timeout)
                    passed = verify_workspace(t, wd)
                    row = {"task": t["name"], "agent": agent, "condition": cond, "passed": passed, **run_info}
                    results.append(row)
                    print(f"{t['name']:18s} {agent:7s} {cond:16s} pass={str(passed):5s} time={row['elapsed_s']}s tokens={row['tokens']} turns={row['tool_calls']}")

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    out = RESULTS_DIR / f"bench-{time.strftime('%Y%m%d-%H%M%S')}.json"
    out.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(f"Saved: {out}")


if __name__ == "__main__":
    main()
