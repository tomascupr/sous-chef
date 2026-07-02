---
name: simmer
description: Runs a loop - Codex implements in fresh iterations while Claude verifies and judges each lap against a machine-checkable goal, until the goal passes or a budget runs out. Use only when the user explicitly asks for a loop ("simmer this", "loop on it until the tests pass", "iterate until green", "run a loop overnight") - it creates a branch and makes checkpoint commits, so confirm the contract before starting. Not for tasks whose success only a human can judge, and not a substitute for a single /sous-chef:fire.
---

# Simmer - reduce until done

A loop is: check state → decide → act → **verify** → repeat, with a stop condition and
a budget. In this kitchen, Codex is the worker inside the loop and you are the loop's
author and judge. The worker never grades its own homework - you run the checks.

If `codex` is missing or `~/.codex/sous-chef.config.toml` doesn't exist, stop and
offer `/sous-chef:mise` first (Codex silently ignores a missing profile - `test -f`).
The repo must have at least one commit (the no-progress guard needs `HEAD`).

## 1. Write the loop contract first - and get it confirmed

A loop is only as good as its stop condition. Establish with the user, and confirm
before lap 1 (simmer creates a branch and makes commits - say so):

- **Goal** - ONE measurable end state, e.g. "`pnpm test` exits 0 with the 12 new
  migration tests passing".
- **Check commands** - the exact commands that verify the goal (tests, typecheck,
  lint, a curl). Machine-checkable or it doesn't belong in a loop: if success can't be
  verified cheaply by a command, don't simmer - do it interactively instead.
- **Budget** - max laps (default 5) and any wall-clock limit. Tell the user the
  realistic wall time: each lap is a full Codex run, typically 5–20 minutes at high
  reasoning effort.
- **Branch** - create `sous-chef/<task>` yourself before lap 1 and tell the user its
  name up front. Never loop directly on main: a bad run must be a branch delete, not
  an incident. If the repo or user config has commit hooks/gates (pre-commit reviews,
  staged-tree checks), resolve how per-lap checkpoints interact with them BEFORE
  lap 1 - ask the user rather than fighting the gate lap after lap.

Write the contract to `$SCRATCHPAD/loop.md` and create a `progress.md` the worker
updates (`$SCRATCHPAD` = your session scratchpad directory - substitute its absolute
path). If the loop should survive this session, keep `loop.md`/`progress.md` on the
branch instead. Each `codex exec` is a fresh context; files and git are the loop's
only memory.

## 2. The lap

For each iteration, until the goal passes or the budget is spent:

1. **Fire the worker** - a fresh backgrounded `codex exec` (same invocation pattern as
   `/sous-chef:fire`, including `env -u CODEX_API_KEY -u CODEX_ACCESS_TOKEN`, `--profile sous-chef`, and a
   fresh per-lap job dir - never reuse result/log paths between laps). The prompt is
   the loop contract plus: lap number, the judge's verdict from last lap (what failed
   and why, verbatim command output), and the instruction to do ONE coherent unit of
   work, update `progress.md`, and stop. Do not poll while it runs.
2. **Verify yourself** - when it exits, first check the job outcome (non-zero exit or
   missing result file = failed lap: read the log tail, surface the error, decide with
   the user whether to retry or stop). Then run the check commands. Their output is
   the verdict; the worker's claims are not.
3. **Checkpoint** - if the tree changed, commit (`simmer <task> lap N`). Git history is
   how a loop survives a bad lap: a regression is a revert, not an argument.
4. **Judge, decide, and say so** - give the user a one-line lap report (lap N of M:
   what changed, check result), then:
   - Checks pass → done. Report laps used, final check output, the commits made, and
     **the branch name** - merging (or deleting) it is the user's call. Offer to
     switch them back to their original branch.
   - Checks fail, progress made → next lap, feeding the failure output back.
   - **No progress** - the tree hash (`git rev-parse HEAD^{tree}` plus a hash of the
     working diff) didn't change, or the same failure repeats twice → stop and
     escalate to the user. A loop that isn't converging doesn't need more laps, it
     needs a different approach (often: you take over, or the ticket was
     under-specified).
   - Budget spent → stop, report honestly where it landed.

## 3. Rails (non-negotiable)

- Lap cap always set - an unbounded loop is a quota incident, not a workflow.
- Verification commands run by you, in your shell, every lap.
- No-progress detection every lap.
- Loops with write access stay on their branch. Merging is a human decision.
- **On interrupt or abort**: kill the worker task, run `git status`, commit or stash
  the partial lap with a clear label (`simmer <task> lap N (interrupted)`), and report
  the branch + last checkpoint so the user knows exactly where their work is.

## Relation to native loop primitives

- `/goal` loops Claude-as-worker with a small-model judge; simmer loops
  **Codex-as-worker with Claude as judge** - use simmer when implementation bulk
  should burn Codex tokens, `/goal` when the work needs Claude itself.
- For recurring maintenance loops (babysit CI, rebase branches, flaky-test repair),
  compose with the harness scheduler: `/loop 30m /sous-chef:simmer …` or a `/schedule`
  routine. Simmer is the inner goal-loop; scheduling is the outer trigger.
