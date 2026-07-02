---
name: simmer
description: Runs a loop — Codex implements in fresh iterations while Claude verifies and judges each lap against a machine-checkable goal, until the goal passes or a budget runs out. Use when the user asks to loop/iterate until done ("keep going until tests pass", "loop on this", "simmer until green"), or for goal-driven work with a cheap verification command. Not for tasks whose success only a human can judge.
---

# Simmer — reduce until done

A loop is: check state → decide → act → **verify** → repeat, with a stop condition and
a budget. In this kitchen, Codex is the worker inside the loop and you are the loop's
author and judge. The worker never grades its own homework — you run the checks.

## 1. Write the loop contract first

A loop is only as good as its stop condition. Before anything runs, establish with the
user (or derive from the task):

- **Goal** — ONE measurable end state, e.g. "`pnpm test` exits 0 with the 12 new
  migration tests passing".
- **Check commands** — the exact commands that verify the goal (tests, typecheck,
  lint, a curl). Machine-checkable or it doesn't belong in a loop: if success can't be
  verified cheaply by a command, don't simmer — do it interactively instead.
- **Budget** — max iterations (default 5) and any wall-clock limit.
- **Blast radius** — significant loops run on a `sous-chef/<task>` branch (or
  worktree), never directly on main, so a bad run is a branch delete, not an incident.

Write the contract to `$SCRATCHPAD/loop.md`, and create a `$SCRATCHPAD/progress.md`
the worker updates (`$SCRATCHPAD` stands for your session scratchpad directory —
substitute its absolute path). Each `codex exec` is a fresh context; files and git are
the loop's only memory.

## 2. The lap

For each iteration, until the goal passes or the budget is spent:

1. **Fire the worker** — a fresh backgrounded `codex exec` (same invocation pattern as
   `/sous-chef:fire`, including `env -u OPENAI_API_KEY` and `--profile sous-chef`).
   The prompt is the loop contract plus: iteration number, the judge's verdict from
   last lap (what failed and why, verbatim command output), and the instruction to do
   ONE coherent unit of work, update `progress.md`, and stop. Do not poll while it runs.
2. **Verify yourself** — when it exits, run the check commands. Their output is the
   verdict; the worker's claims are not.
3. **Checkpoint** — if the tree changed, commit (`simmer <task> lap N`). Git history is
   how a loop survives a bad lap: a regression is a revert, not an argument.
4. **Judge and decide**:
   - Checks pass → done. Report laps used, final check output, commits made.
   - Checks fail, progress made → next lap, feeding the failure output back.
   - **No progress** — the tree hash didn't change, or the same failure repeats twice →
     stop and escalate to the user. A loop that isn't converging doesn't need more
     laps, it needs a different approach (often: you take over, or the ticket was
     under-specified).
   - Budget spent → stop, report honestly where it landed.

## 3. Rails (non-negotiable)

- Iteration cap always set — an unbounded loop is a quota incident, not a workflow.
- Verification commands run by you, in your shell, every lap.
- No-progress detection every lap (hash the tree: `git rev-parse HEAD^{tree}` +
  working-diff hash).
- Loops with write access stay on their branch. Merging is a human decision.

## Relation to native loop primitives

- `/goal` loops Claude-as-worker with a small-model judge; simmer loops
  **Codex-as-worker with Claude as judge** — use simmer when implementation bulk
  should burn Codex tokens, `/goal` when the work needs Claude itself.
- For recurring maintenance loops (babysit CI, rebase branches, flaky-test repair),
  compose with the harness scheduler: `/loop 30m /sous-chef:simmer …` or a `/schedule`
  routine. Simmer is the inner goal-loop; scheduling is the outer trigger.
