---
name: refire
description: Turns validated review findings into a scoped fix run. Use after /sous-chef:taste when the user says to fix the findings, apply the review, or refire it. Takes the CONFIRMED findings (or a review the user pastes), fires a fix ticket at the implementer, then re-verifies each finding at its cited location. Not for new feature work; that is a fresh /sous-chef:fire.
---

# Refire: the plate failed the pass, send it back

A refire is a fix run with the review as its spec. The findings are already validated
(that was taste's job), so the ticket is unusually precise: file, line, failure
scenario, prescribed fix. Your job is to carry that precision through and then prove
each finding is actually gone.

## Inputs

- Default: the CONFIRMED findings from the most recent `/sous-chef:taste` in this
  session.
- Alternative: a review the user pastes or points to. Validate unfamiliar findings
  against the code first (taste's step 3); never refire a finding you have not
  confirmed yourself.
- No findings available? Say so and stop. Refire without a review is just a fire.

## Preflight

Same as fire, and for the same reasons:

1. Git repo with at least one commit (`git rev-parse HEAD`).
2. `test -f ~/.codex/sous-chef.config.toml`; missing means stop and offer
   `/sous-chef:mise` (Codex silently ignores a missing profile).
3. Snapshot the tree: save `git diff` and `git status --short` into the job dir as the
   baseline. The tree usually is dirty here (it holds the diff that was just tasted);
   that is expected, the baseline is what separates the tasted diff from the refire's
   changes.
4. Mint a fresh job dir: `JOB=$(mktemp -d "$SCRATCHPAD/refire-XXXXXX")`
   (`$SCRATCHPAD` is your session scratchpad directory; substitute its absolute path).

## The refire ticket

Write `$JOB/ticket.md` with the fire template's XML blocks, specialized:

- `<task>`: "Fix the review findings below. Each is confirmed against the code."
  Then one block per finding: file:line, the defect in one sentence, the evidence
  (quoted code), and the prescribed fix.
- `<done_when>`: every listed finding resolved at its cited location, plus the repo's
  verification commands passing.
- `<files>`: touch only files named in the findings. Everything else is off limits.
- `<constraints>`: fix ONLY the findings; no drive-by improvements, no refactors of
  surrounding code, no reformatting.
- `<verification>`: the repo's check commands.
- `<output_contract>`: CHANGED / VERIFIED / OPEN, with a per-finding line under
  CHANGED stating how each was resolved.

## Firing and plating

Identical to fire: backgrounded profiled run from the repo root, announce it in one
line (what, which model, expected minutes, log path, cancel offer), no polling.

At plating, in addition to fire's outcome checks (exit code, result file present,
sandbox banner):

1. Open each finding's cited location and confirm the defect is gone. A finding-by-
   finding checklist, not a vibe.
2. Run the verification commands yourself.
3. Diff against the pre-refire baseline: only finding-scoped changes should appear.
   Anything else gets reverted or flagged to the user.
4. For risky diffs, offer a confirmation `/sous-chef:taste`; two clean models in a row
   is the strongest ship signal this kitchen produces.

## Cap

One refire per taste. If a finding survives its refire, do not loop: fix it yourself
or bring it back to the user with what was tried. (Same diminishing-returns rule as
fire's two-delta cap.)
