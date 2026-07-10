---
name: simmer
description: Runs a goal loop - Codex implements fresh laps while Claude verifies each against a machine-checkable goal, until it passes or the budget runs out. Use only when the user explicitly asks for a loop ("simmer this", "loop until tests pass", "iterate until green") - it creates a branch and checkpoint commits, so confirm the contract first.
---

# Simmer - reduce until done

A loop is: check state → decide → act → **verify** → repeat, with a stop condition and
a budget. In this kitchen, Codex is the worker inside the loop and you are the loop's
author and judge. The worker never grades its own homework - you run the checks. And
because each `codex exec` is a fresh context while your own conversation can be
compacted or restarted mid-loop, neither of you is the loop's memory: the repo is.

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

## 2. Loop state - in the repo, out of git

Add `.sous-chef/` to `$(git rev-parse --git-path info/exclude)` if it isn't there
yet, then write the contract (goal, check commands, budget, branch with its base
commit, and the UTC start time as a `started:` line - the receipt reads it back for
wallclock, same field name as serve's state.md) to
`.sous-chef/loop.md` and create `.sous-chef/progress.md`. The state survives session
restarts because it lives in the repo; the ignore keeps it out of diffs, checkpoint
commits, and the no-progress guard.

Ownership is strict: `loop.md` is yours - the contract plus one verdict line per lap
under `## Laps`; `progress.md` is the worker's notebook. The worker never writes
`loop.md`.

If `.sous-chef/loop.md` already exists at invocation, this is a resume: on a task
match, switch to the recorded branch (it still existing is part of the match) and
start where the loop definition starts - check state: run the check commands, and if
the goal already passes, that's a done report, not a lap. Otherwise count the budget
from the `## Laps` lines - and prove the fate of any `fired` line with no verdict
via its recorded job dir before counting it: a result file present means the run
landed unjudged (judge it now, rewrite the line); a log still growing means the
worker is still cooking - NEVER fire a second worker into the same tree, wait for
it or surface it; neither means it died in flight, and it counts as spent. Lines
before the most recent `pass` belong to a finished episode, so a regression after
a pass counts laps fresh (the cycling guard still reads all of them). This is what lets a `/loop` trigger on the same machine re-enter
a simmer. If the task differs or the branch is gone, the loop is stale: show it to
the user before starting fresh.

## 3. The lap

For each iteration, until the goal passes or the budget is spent:

1. **Fire the worker** - a fresh backgrounded `codex exec` (same invocation pattern as
   `/sous-chef:fire`, including its backgrounding rule - no `&`, `nohup`, or `disown`
   inside the command - `env -u CODEX_API_KEY -u CODEX_ACCESS_TOKEN`, `--profile sous-chef`, and a
   fresh per-lap job dir - never reuse result/log paths between laps). The prompt is
   the full contents of `.sous-chef/loop.md` (contract plus lap history) plus: lap
   number, the verbatim failing output from last lap, and the instruction to do ONE
   coherent unit of work, update `.sous-chef/progress.md` (never `loop.md` - that
   file is the judge's), and stop. When you launch, append `lap N: fired <abs job
   dir>` under `## Laps` - the budget counts launches, not landings, so a crash
   mid-lap can't un-spend a lap, and the job dir is how a later resume proves this
   run's fate. Do not poll while it runs; progress ticks, if the user has them on,
   follow fire's "While it cooks" - armed per lap, disarmed at lap exit.
2. **Verify yourself** - when it exits, first check the job outcome (non-zero exit or
   missing result file = failed lap: rewrite its line to `lap N: fail - run error:
   <cause>`, read the log tail, surface the error, and decide with the user whether
   to retry - a retry is a new launch under the next lap number - or stop). Then run
   the check commands. Their output is
   the verdict; the worker's claims are not. Record it: rewrite lap N's `fired` line
   to the verdict - `lap N: pass` or `lap N: fail - <first failing command>:
   <error identity>`. Strip timestamps, durations, and temp paths so an identical
   failure produces an identical line, but keep the failing test or error name -
   `pnpm test: FAIL` is too coarse to mean anything. You write these lines, never
   the worker: they are the loop's durable lap counter and its convergence evidence.
3. **Checkpoint** - if the tree changed, commit (`simmer <task> lap N`). Git history is
   how a loop survives a bad lap: a regression is a revert, not an argument.
4. **Judge, decide, and say so** - give the user a one-line lap report (lap N of M:
   what changed, check result) and add the lap to the running tab per fire's plating -
   same `~/.sous-chef/ledger.jsonl` line with `"skill":"simmer"` plus `"lap":N`, pass
   or fail (a failed lap still spent quota; no token summary in the log means no
   line). Then:
   - Checks pass → done. Report laps used, final check output, the commits made, and
     **the branch name** - merging (or deleting) it is the user's call. Mention that
     `.sous-chef/loop.md` and `progress.md` are loop scaffolding they can drop, while
     `.sous-chef/receipts/` keeps the repo's run receipts; don't delete either
     unasked. Offer to switch them back to their original branch.
   - Checks fail, progress made → next lap, feeding the failure output back.
   - **No progress or cycling** - the tree hash (`git rev-parse HEAD^{tree}` plus a
     hash of the working diff) didn't change, or this lap's failure signature already
     appears in any earlier `## Laps` line (the loop is circling, not converging) →
     stop and escalate to the user. A loop that isn't converging doesn't need more
     laps, it needs a different approach (often: you take over, or the ticket was
     under-specified).
   - Budget spent → stop, report honestly where it landed.

   Whatever the terminal outcome, write the run's receipt per
   [../receipts/references/receipt-template.md](../receipts/references/receipt-template.md).

## 4. Rails (non-negotiable)

- Lap cap always set - an unbounded loop is a quota incident, not a workflow.
- Verification commands run by you, in your shell, every lap.
- No-progress and cycling detection every lap, judged from the `## Laps` lines you
  wrote - the lap cap, not the guard, remains the primary safety.
- Loops with write access stay on their branch. Merging is a human decision.
- **On interrupt or abort**: kill the worker task, run `git status`, commit or stash
  the partial lap with a clear label (`simmer <task> lap N (interrupted)`), rewrite
  the lap's `fired` line to `lap N: interrupted`, and report the branch + last
  checkpoint so the user knows exactly where their work is.

## Relation to native loop primitives

- `/goal` loops Claude-as-worker with a small-model judge; simmer loops
  **Codex-as-worker with Claude as judge** - use simmer when implementation bulk
  should burn Codex tokens, `/goal` when the work needs Claude itself.
- For recurring maintenance loops (babysit CI, rebase branches, flaky-test repair),
  compose with `/loop 30m /sous-chef:simmer …` - same machine, same working tree, so
  a fresh session finds `.sous-chef/loop.md` and resumes at the recorded lap. A cloud
  `/schedule` routine runs on a fresh clone and never sees local loop state - don't
  compose simmer with it.
