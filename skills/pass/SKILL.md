---
name: pass
description: Cross-model code review — Codex (GPT-5.5) reviews the current diff read-only, then Claude validates every finding against the actual codebase before presenting it. Use before committing significant diffs, after completing a feature, or when the user asks for a second opinion / cross-review. Not needed for trivial or docs-only changes.
---

# Pass — every plate crosses the pass before it leaves the kitchen

A reviewer from a different training lineage doesn't share your blind spots — cross-model review reliably catches edge-case bugs that self-review misses. But raw Codex findings over-flag, so every finding gets validated before it reaches the user.

## 1. Scope the diff

```bash
git status --short --untracked-files=all
git diff --shortstat && git diff --shortstat --cached
```

- Working-tree review (default): staged + unstaged + untracked count as reviewable.
- Branch review (user said "review this branch/PR"): scope with `git diff <base>...HEAD`.
- Empty scope → say there's nothing to review; don't run Codex on nothing.

## 2. Run the review — read-only, in the background

Build the review prompt from [references/review-prompt.md](references/review-prompt.md), filling in the diff scope and any focus the user gave. (`$SCRATCHPAD` below stands for your session scratchpad directory — substitute its absolute path.) Then:

```
Bash (run_in_background: true):
env -u OPENAI_API_KEY codex exec --profile sous-chef --sandbox read-only \
  --output-last-message "$SCRATCHPAD/review-result.md" \
  - < "$SCRATCHPAD/review-prompt.md" > "$SCRATCHPAD/review-job.log" 2>&1
```

`--sandbox read-only` overrides the profile's workspace-write — CLI flags beat profile settings. The reviewer must not be able to "fix" anything; review and implementation stay separate roles. Do not poll while it runs.

For production-critical code (auth, payments, data storage, external APIs), add the adversarial framing from the reference file — but only there. Adversarial mode over-flags small codebases with enterprise-pattern findings.

## 3. Validate before presenting — this step is the point

Codex reviews have documented failure modes: findings calibrated to the wrong project scale, plausible-sounding issues that don't survive contact with the code, and occasional shallow passes. So for EACH finding:

1. Open the cited file/line and check the claim against the actual code.
2. Label it CONFIRMED (you verified the failure scenario is real) or REFUTED (state why — guard exists upstream, dead path, intentional per repo conventions, wrong about the API).
3. Drop REFUTED findings from the main report; mention only their count.

## 4. Report

Lead with the verdict (ship / fix first), then confirmed findings ordered by severity, each with file:line, the failure scenario in one sentence, and the fix. Close with "N findings refuted on validation" if any. Do not apply fixes unless the user asked for that — the deliverable of a review is the assessment.

## Notes

- If OpenAI's official `codex` plugin is installed, `/codex:review` also exists. `/sous-chef:pass` differs on purpose: pinned read-only sandbox, scale-calibrated prompt, and the mandatory validation pass that filters false positives.
- Two models agreeing after independent review is a strong ship signal; divergence means design a discriminating test, not a longer argument.
