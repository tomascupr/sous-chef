---
name: serve
description: Runs the whole line autonomously - implement via Codex, cross-review, fix confirmed findings, verify, report once at the end. Use when the user wants a task done end to end ("serve this", "just get it done"), or as the default for spec-able implementation when the routing policy is autonomous. Announces once; stops only for hard blockers.
---

# Serve - the whole line, one order

Serve is fire, taste, and refire composed into one autonomous pass. Each stage follows
its sibling skill exactly; this skill only adds the autonomy contract that connects
them.

## The pipeline

1. **Fire** - per `/sous-chef:fire`: preflight, ticket, backgrounded run, plating with
   your own verification. If plating fails verification, one delta round (it counts
   against the serve budget). The pipeline advances only on green verification: still
   red after the delta means fix it yourself if a surgical fix will do, otherwise stop
   and report honestly - tasting a known-broken implementation wastes the remaining
   budget.
2. **Taste** - per `/sous-chef:taste`: read-only cross-review scoped to the delta
   against stage 1's pre-fire baseline - the user's pre-existing WIP is not part of
   this order - then your validation pass. Skip only if the diff is trivial (a few
   lines); say so in the final report.
3. **Refire** - per `/sous-chef:refire`: if any findings were CONFIRMED, one scoped
   fix run, then re-verify each finding at its cited location.
4. **Plate** - run the verification commands one final time and serve.

## Autonomy contract

- Announce ONCE before stage 1: the task, the model, and that this is a full serve
  (typically 2-3 Codex runs, expect 15-45 minutes at high reasoning effort). Then run
  the pipeline without asking anything between stages.
- Only interrupt the user for hard blockers: a failed run with an error they must act
  on (auth, quota), verification still red after stage 1's delta (and any surgical
  fix of your own), a finding that survived its refire, or preflight failures.
- Every safety rule of the underlying skills still applies: background always, never
  poll, per-job dirs, outcome checks before trusting results, baseline-aware diffs.
- Budget: at most 5 Codex runs total (fire, one delta if needed, taste, refire,
  optional confirmation taste). If the work is not done inside the budget, stop and
  report honestly where it stands; if what remains is goal-shaped (a check command
  that must pass), offer to continue as `/sous-chef:simmer` rather than overrunning.

## The final report

One message: what shipped (files, summary), what taste found (confirmed findings and
how the refire resolved them; refuted count), the verification output you ran
yourself, and anything OPEN. If all stages came back clean, say so plainly - two
models in agreement, checks green, plate served.

## When NOT to serve

- Ambiguous design work: resolve the approach first, then serve.
- Goal-loop work ("iterate until the benchmark improves"): that is `/sous-chef:simmer`.
- When the user wants to review between stages: use fire, taste, refire individually.
