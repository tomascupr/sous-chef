---
name: refire
description: Turns confirmed findings from a taste into one scoped fix run, then re-verifies each finding at its cited location. Use after /sous-chef:taste when the user says to fix the findings, apply the review, or refire it. Not for new feature work - that is a fresh /sous-chef:fire.
---

# Refire - the plate failed the pass, send it back

A refire is a fix run whose spec already exists on disk: the `findings.md` a taste
wrote after validating every finding. That is what makes the ticket unusually
precise - file, line, failure scenario, prescribed fix, all confirmed against the
code. Your job is to carry that precision through and then prove each finding is
actually gone.

## Inputs

- Default: the `findings.md` the most recent `/sous-chef:taste` wrote - its report
  names the path; inside `/sous-chef:serve` it is the `findings:` line in the run's
  `state.md`. (Lost the path? It's the newest `findings.md` under `$SCRATCHPAD`.)
- Alternative: a review the user pastes or points to. Validate unfamiliar findings
  against the code first (taste's step 3); never refire a finding you have not
  confirmed yourself.
- No findings available? Say so and stop. Refire without a review is just a fire.

## Preflight

Same as fire, and for the same reasons:

1. Git repo with at least one commit (`git rev-parse HEAD`).
2. `test -f ~/.codex/sous-chef.config.toml`; missing means stop and offer
   `/sous-chef:mise` (Codex silently ignores a missing profile).
3. Mint a fresh job dir: `JOB=$(mktemp -d "$SCRATCHPAD/refire-XXXXXX")`
   (`$SCRATCHPAD` is your session scratchpad directory; substitute its absolute path).
4. Snapshot the tree: save `git diff` and `git status --short` into `$JOB` as the
   baseline. The tree is usually dirty here (it holds the diff that was just tasted);
   that is expected; the baseline is what separates the tasted diff from the refire's
   changes.
5. Anchor check: recompute
   `$(git rev-parse --short HEAD)+$(idx=$(mktemp -u); GIT_INDEX_FILE=$idx git add -A && GIT_INDEX_FILE=$idx git write-tree | cut -c1-12)`
   and compare it to the `tree:` line in the findings' header. On mismatch - or no
   `tree:` line at all - the tree has moved since the taste and the cited line numbers
   may have drifted: say so, then treat the file as an unvalidated review (the Inputs
   rule above) - revalidate each finding at its cited location before writing the
   ticket, dropping any that no longer hold.

## The refire ticket

Write `$JOB/ticket.md` with the fire template's XML blocks, specialized:

- `<task>`: "Fix the review findings below. Each is confirmed against the code."
  Then one block per finding: file:line, the defect in one sentence, the evidence
  (quoted code), and the prescribed fix. Taste's `findings.md` is already in this
  shape - carry its CONFIRMED blocks over near-verbatim; its refuted audit-trail
  section is not refire input.
- `<done_when>`: every listed finding resolved at its cited location, plus the repo's
  verification commands passing.
- `<files>`: touch only files named in the findings. Everything else is off limits.
- `<constraints>`: fix ONLY the findings; no drive-by improvements, no refactors of
  surrounding code, no reformatting.
- `<verification>`: the repo's check commands.
- `<output_contract>`: CHANGED / VERIFIED / OPEN, with a per-finding line under
  CHANGED stating how each was resolved.

## Firing and plating

Identical to fire, backgrounding rule included: backgrounded profiled run from the
repo root, announce it in one line (what, which model, expected minutes, log path,
cancel offer), no polling. Fire's ledger line applies too, with `"skill":"refire"`.

At plating, in addition to fire's outcome checks (exit code, result file present,
sandbox banner):

1. Open each finding's cited location and confirm the defect is gone. A
   finding-by-finding checklist, not a vibe.
2. Run the verification commands yourself.
3. Diff against the pre-refire baseline and compare the changed file set to the
   ticket's `<files>` Touch list, using fire's concurrent-edit rule. Name outside-list
   files, warn `concurrent edit detected - these changes are NOT part of this run's
   review`, exclude them from the refire-attributed delta, and revert or flag worker
   out-of-scope changes.
4. For risky diffs, offer a confirmation `/sous-chef:taste`; two clean models in a row
   is the strongest ship signal this kitchen produces.

## The 86 list - make the confirmed defect persistent

"86'd" is kitchen slang for struck from the menu. `.sous-chef/86.md` is this repo's 86
list: patterns confirmed as defects here by past taste/refire cycles, committed like
`AGENTS.md`. Fire injects it into new tickets and taste into review prompts, so the next
worker stops reintroducing them and the next reviewer knows where to look. It is the only
place a validated finding outlives the serve that found it.

Write to it ONLY from findings that cleared step 1 above - re-verified real, then fixed.
Never from raw taste output; the re-verification is the evidence bar, and the list records
only what passed it. This is the load-bearing rule of the whole feature. For each finding
you just confirmed and resolved:

1. **Generalize the pattern from the instance** - "silent catch blocks swallowing errors
   in async handlers", not "line 42 of foo.ts". The next run breaks at a different line.
2. **Append one line** to `.sous-chef/86.md`, creating the file (and `.sous-chef/`) if
   absent:
   `- [YYYY-MM-DD] <one-line pattern> (evidence: file:line, <serve or task ref>)`
3. **Dedupe:** if an equivalent pattern is already listed, bump its date instead of
   adding a duplicate.
4. **Hard cap 15 entries.** If appending would exceed it, drop the oldest entry whose
   pattern has not recurred (its date was never bumped). One line per entry is a
   correctness property, not style - this file is injected verbatim into fire tickets and
   taste prompts, so brevity keeps it cheap to carry.

Commit `.sous-chef/86.md` alongside the fix; it is a team asset, not a scratch file.

## Cap

One refire per taste. If a finding survives its refire, do not loop: fix it yourself
or bring it back to the user with what was tried. (Same diminishing-returns rule as
fire's two-delta cap.)
