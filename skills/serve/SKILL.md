---
name: serve
description: Runs the whole line autonomously - implement via Codex, cross-review, fix confirmed findings, verify, report once at the end. Use when the user wants a task done end to end ("serve this", "just get it done"), or as the default for spec-able implementation when the routing policy is autonomous. Announces once; stops only for hard blockers.
---

# Serve - the whole line, one order

Serve is fire, taste, and refire composed into one autonomous pass. Each stage
follows its sibling skill exactly; serve adds only what connects them: a run state
file that outlives your context, and an autonomy contract that replaces the
per-stage conversation.

## Run state - the ticket on the rail

Before stage 1, mint one run dir: `RUN=$(mktemp -d "$SCRATCHPAD/serve-XXXXXX")`.
Each stage mints its job dir per its sibling skill, but inside `$RUN` (substitute
`$RUN` for `$SCRATCHPAD` in the sibling's mktemp) - even with a stale state file,
`ls "$RUN"` reconstructs the run. Keep `$RUN/state.md`, a few self-describing lines
rewritten in full at every stage transition:

```
task: <one line>
started: <UTC ISO-8601 of stage 1's fire>
budget: 5
runs_used: 2 (fire, taste)
stage: taste plated; next: refire
baseline: <abs path to stage 1's pre-fire.patch>
findings: <abs path to taste's findings.md>
job: <abs path to the job dir currently cooking, if any>
```

Bump `runs_used` when a run is launched, not when it lands - a compaction while a
job is in flight must not un-spend the budget. The conversation is not the ledger of
this run; state.md is. After compaction, or on any doubt about the count, read it
before firing anything. (A `/clear` or session death mints a new scratchpad - serve
is a single-session promise and does not survive that; the working tree and job
dirs still hold the work.)

## Choosing the worker

If the arguments begin with `--with <worker>` (see fire's worker table), the
choice applies to the whole line: fire and refire run on that worker; taste
stays on Codex read-only when available, which makes the review cross-model
when the worker is not Codex. Record the worker in `state.md` (`worker: sonnet`).

Whenever implementer and reviewer share a lineage, say so in the final report.
The default all-Codex line always does: Codex reviews its own diff (fresh
context - `codex exec` carries no session memory - but same lineage), so
Claude's validation pass is the only cross-model check in that run.

## The pipeline

1. **Fire** - per `/sous-chef:fire`: preflight, ticket, backgrounded run, plating with
   your own verification. Record the job's `pre-fire.patch` path as `baseline:` in
   state.md - later stages scope against it. If plating fails verification, one delta
   round (it counts against the serve budget). The pipeline advances only on green
   verification: still red after the delta means fix it yourself if a surgical fix
   will do, otherwise stop and report honestly - tasting a known-broken
   implementation wastes the remaining budget.
2. **Taste** - per `/sous-chef:taste`: read-only cross-review scoped to the delta
   against the `baseline:` patch in state.md - the user's pre-existing WIP is not
   part of this order - then your validation pass; record the resulting
   `findings.md` path as `findings:`. Skip only if the diff is trivial (a few
   lines); say so in the final report.
3. **Refire** - per `/sous-chef:refire`: if the `findings:` file lists any CONFIRMED
   findings, one scoped fix run, then re-verify each finding at its cited location.
4. **Plate** - run the verification commands one final time and serve.

Stage transitions inherit fire/refire's changed-files-vs-`<files>` concurrent-edit
check; outside-list paths are named, warned, and excluded from the stage delta.

## Autonomy contract

- Announce ONCE before stage 1: the task, the model, and that this is a full serve
  (typically 2-3 Codex runs, expect 15-45 minutes at high reasoning effort). Then run
  the pipeline without asking anything between stages; a one-line tick as each stage
  completes ("fire plated, checks green - tasting now") keeps a long serve legible.
  No-asking is the contract, not silence.
- Progress ticks are on by default: while a Codex run cooks, keep a self-paced wakeup
  loop armed per fire's "While it cooks" - one distilled line every few minutes from
  the running job's log, disarmed the moment the run exits. Each tick reads
  `$RUN/state.md` (its `job:` line names the log to tail), not conversation memory,
  so ticks survive compaction. A serve asks for 15-45 unattended minutes; the ticks
  are what make that tolerable.
- Only interrupt the user for hard blockers: a failed run with an error they must act
  on (auth, quota), verification still red after stage 1's delta (and any surgical
  fix of your own), a finding that survived its refire, or preflight failures.
- Every safety rule of the underlying skills still applies: background always (fire's
  backgrounding rule included - never nest `&`, `nohup`, or `disown` in the command),
  never poll, per-job dirs, outcome checks before trusting results, baseline-aware diffs.
- Budget: at most 5 Codex runs total (fire, one delta if needed, taste, refire,
  optional confirmation taste). The count lives in `$RUN/state.md`, not in your
  context. Failed runs and retries count - the budget is quota spend, not useful
  output - so when a retry eats a slot, the confirmation taste is the first thing
  dropped; say so in the final report. If the work is not done inside the budget,
  stop and report honestly where it stands; if what remains is goal-shaped (a check
  command that must pass), offer to continue as `/sous-chef:simmer` rather than
  overrunning.

## The final report

One message: what shipped (files, summary), what taste found (confirmed findings and
how the refire resolved them; refuted count), the verification output you ran
yourself, and anything OPEN. If all stages came back clean, say so plainly - two
models in agreement, checks green, plate served.

Then write the run's receipt to `.sous-chef/receipts/` per
[../receipts/references/receipt-template.md](../receipts/references/receipt-template.md)
and, when the verdict is verified, end the report with its shareable summary line.
Receipt numbers come from the job logs, your own verification, and the diff against
`baseline:` - a line you can't back with a measurement gets dropped, not guessed.

## When NOT to serve

- Ambiguous design work: resolve the approach first, then serve.
- Goal-loop work ("iterate until the benchmark improves"): that is `/sous-chef:simmer`.
- When the user wants to review between stages: use fire, taste, refire individually.
