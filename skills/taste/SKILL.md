---
name: taste
description: Cross-model code review - Codex reviews the current diff read-only, then Claude validates every finding against the actual codebase before presenting it. Use when the user asks for a review, a second opinion, or a cross-model check of a diff or branch. On-demand only - don't run it automatically before commits; offer it when a diff is large or risky and let the user decide.
---

# Taste - the chef tastes every plate before it leaves the kitchen

A reviewer from a different training lineage doesn't share your blind spots - cross-model review reliably catches edge-case bugs that self-review misses. But raw Codex findings over-flag, so every finding gets validated before it reaches the user.

If `codex` is missing or `~/.codex/sous-chef.config.toml` doesn't exist, stop and offer `/sous-chef:mise` (Codex silently ignores a missing profile - check with `test -f`, don't rely on an error).

## 1. Scope the diff

```bash
git status --short --untracked-files=all
git diff --shortstat && git diff --shortstat --cached
```

- Working-tree review (default): staged + unstaged + untracked count as reviewable.
- Branch review (user said "review this branch/PR"): scope with `git diff <base>...HEAD`.
- Empty scope → say there's nothing to review; don't run Codex on nothing.
- **Large diffs review shallow.** If the scope exceeds ~1,500 changed lines, split into per-area passes or agree a focus with the user - and say that's why.

## 2. Run the review - read-only, in the background

Mint a job dir (`JOB=$(mktemp -d "$SCRATCHPAD/taste-XXXXXX")`, where `$SCRATCHPAD` is your session scratchpad directory - substitute its absolute path). Build the review prompt from [references/review-prompt.md](references/review-prompt.md), filling in the diff scope and any focus the user gave, then:

```
Bash (run_in_background: true), cwd = repo root:
env -u CODEX_API_KEY -u CODEX_ACCESS_TOKEN codex exec --profile sous-chef --sandbox read-only \
  --output-last-message "$JOB/result.md" \
  - < "$JOB/review-prompt.md" > "$JOB/job.log" 2>&1
```

`--sandbox read-only` overrides the profile's workspace-write - CLI flags beat profile settings. The reviewer must not be able to "fix" anything; review and implementation stay separate roles.

Tell the user the review is running, that it can take several minutes on a real diff, and where the log lives. Do not poll while it runs.

For production-critical code (auth, payments, data storage, external APIs), add the adversarial framing from the reference file - but only there. Adversarial mode over-flags small codebases with enterprise-pattern findings.

## 3. Validate before presenting - this step is the point

First check the run itself: if the job exited non-zero, or `$JOB/result.md` is missing, empty, or has no `VERDICT:` line, the review failed - show the user the tail of the log verbatim and offer a rerun or reviewing it yourself. **Never present a missing or malformed review as "no findings - ship".** (Silent review failures are a documented Codex failure mode.)

Then, for EACH finding:

1. Open the cited file/line and check the claim against the actual code.
2. Label it CONFIRMED (you verified the failure scenario is real) or REFUTED (state why - guard exists upstream, dead path, intentional per repo conventions, wrong about the API).
3. Drop REFUTED findings from the main report; mention only their count.

## 4. Report

Lead with the verdict (ship / fix first), then confirmed findings ordered by severity, each with file:line, the failure scenario in one sentence, and the fix. Close with "N findings refuted on validation" if any. Do not apply fixes unless the user asked for that - the deliverable of a review is the assessment.

## Notes

- If OpenAI's official `codex` plugin is installed, `/codex:review` also exists. `/sous-chef:taste` differs on purpose: pinned read-only sandbox, scale-calibrated prompt, and the mandatory validation pass that filters false positives.
- Two models agreeing after independent review is a strong ship signal; divergence means design a discriminating test, not a longer argument.
