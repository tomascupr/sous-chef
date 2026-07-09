---
name: taste
description: Cross-model code review - Codex reviews the diff read-only, then Claude validates every finding against the code before presenting it. Use when the user asks for a review, a second opinion, or a cross-model check. Offer it for large or risky diffs; invoke it directly only when the routing policy is autonomous.
---

# Taste - the chef tastes every plate before it leaves the kitchen

A reviewer from a different training lineage doesn't share your blind spots - cross-model review reliably catches edge-case bugs that self-review misses. But raw Codex findings over-flag, so nothing reaches the user unvalidated: the deliverable of a taste is the CONFIRMED set, written to disk where a refire can pick it up.

If `codex` is missing or `~/.codex/sous-chef.config.toml` doesn't exist, stop and offer `/sous-chef:mise` (Codex silently ignores a missing profile - check with `test -f`, don't rely on an error).

## 1. Scope the diff

```bash
git status --short --untracked-files=all
git diff --shortstat && git diff --shortstat --cached
```

- Working-tree review (default): staged + unstaged + untracked count as reviewable.
- Branch review (user said "review this branch/PR"): scope with `git diff <base>...HEAD`.
- Post-fire review (a pre-fire baseline exists - inside `/sous-chef:serve`, or tasting
  a fire's result on a tree that was dirty before the fire): the change under review
  is the delta since that baseline, never the whole tree. Scope the prompt to it -
  name the files the run touched, and point at the baseline patch for files that mix
  fired changes with prior WIP. Findings against pre-existing WIP would send a refire
  rewriting the user's own uncommitted work; say in the report that WIP was excluded.
- Empty scope → say there's nothing to review; don't run Codex on nothing.
- **Large diffs review shallow.** If the scope exceeds ~1,500 changed lines, split into per-area passes or agree a focus with the user - and say that's why.

## 2. Run the review - read-only, in the background

Mint a job dir (`JOB=$(mktemp -d "$SCRATCHPAD/taste-XXXXXX")`, where `$SCRATCHPAD` is your session scratchpad directory - substitute its absolute path). Build the review prompt from [references/review-prompt.md](references/review-prompt.md), filling in the diff scope and any focus the user gave. If `.sous-chef/86.md` exists and has entries, paste them verbatim into the reference file's `<known_failure_modes>` slot - the repo's 86 list, the patterns past taste/refire cycles confirmed as defects here, offered as a secondary focus so the reviewer checks the delta against them first. It biases attention only; findings still need grounding per `<grounding_rules>`, and the list never lowers that bar. Then:

```
Bash (run_in_background: true), cwd = repo root:
env -u CODEX_API_KEY -u CODEX_ACCESS_TOKEN codex exec --profile sous-chef --sandbox read-only \
  --output-last-message "$JOB/result.md" \
  - < "$JOB/review-prompt.md" > "$JOB/job.log" 2>&1
```

Same backgrounding rule as fire: do not put `&`, `nohup`, or `disown` inside the command, or the harness can report false completion while Codex is still running.

`--sandbox read-only` overrides the profile's workspace-write - CLI flags beat profile settings. The reviewer must not be able to "fix" anything; review and implementation stay separate roles.

Tell the user the review is running, that it can take several minutes on a real diff, and where the log lives. Do not poll while it runs.

For production-critical code (auth, payments, data storage, external APIs), add the adversarial framing from the reference file - but only there. Adversarial mode over-flags small codebases with enterprise-pattern findings.

## 3. Validate before presenting - this step is the point

First check the run itself: if the job exited non-zero, or `$JOB/result.md` is missing, empty, or has no `VERDICT:` line, the review failed - show the user the tail of the log verbatim and offer a rerun or reviewing it yourself. **Never present a missing or malformed review as "no findings - ship".** (Silent review failures are a documented Codex failure mode.)

Then, for EACH finding:

1. Open the cited file/line and check the claim against the actual code.
2. Label it CONFIRMED (you verified the failure scenario is real) or REFUTED (state why - guard exists upstream, dead path, intentional per repo conventions, wrong about the API).
3. Drop REFUTED findings from the main report; mention only their count - except a
   refuted blocker/major, which the report names with its refutation reason: a wrong
   refutation on a serious finding must be visible enough for the user to overrule.

Then write the CONFIRMED set to `$JOB/findings.md`: a header line (verdict, scope, refuted count), then one block per finding - severity, file:line, the defect in one sentence, the quoted evidence, the prescribed fix. After the confirmed blocks, add a `## Refuted (audit trail - not refire input)` section: one line per refuted finding - severity, file:line, the claim, and why it fell. A REFUTED verdict is an unreviewed judgment call; persisting the reasoning is what makes it auditable later instead of dying with the session. Add a tree anchor to the header - `tree: $(git rev-parse --short HEAD)+$(idx=$(mktemp -u); GIT_INDEX_FILE=$idx git add -A && GIT_INDEX_FILE=$idx git write-tree | cut -c1-12)` (the temp-index write-tree makes untracked files count - a fire's newly created files are exactly what findings cite) - so a later refire can tell whether these file:line citations still describe the tree it is about to fire into. Write the file even when clean (`CONFIRMED: none`) so a clean taste is distinguishable from no taste. This file is the handoff to `/sous-chef:refire` - validated once, carried on disk, never reconstructed from memory.

## 4. Report

Lead with the verdict (ship / fix first), then confirmed findings ordered by severity, each with file:line, the failure scenario in one sentence, and the fix. Close with "N findings refuted on validation" if any, plus the run's token usage from the log's closing summary - and add the run to the tab per fire's plating (same `~/.sous-chef/ledger.jsonl` line, with `"skill":"taste"`). Name the absolute `$JOB/findings.md` path in the report. Do not apply fixes unless the user asked for that - the deliverable of a review is the assessment. If the user wants the confirmed findings fixed, that is `/sous-chef:refire`, and the findings file is its input.

## Notes

- If OpenAI's official `codex` plugin is installed, `/codex:review` also exists. `/sous-chef:taste` differs on purpose: pinned read-only sandbox, scale-calibrated prompt, and the mandatory validation pass that filters false positives.
- Two models agreeing after independent review is a strong ship signal; divergence means design a discriminating test, not a longer argument.
- Inside `/sous-chef:serve`, taste runs as a pipeline stage the user ordered up front - deliberate, budgeted scope, not an unbounded stop-time or pre-commit review gate.
