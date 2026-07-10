# Receipt template - what serve and simmer write

At the end of every serve and simmer - any terminal outcome, verified or halted
or budget spent - write one file to `.sous-chef/receipts/` in the repo root:

- Filename - `$(date -u +%Y%m%dT%H%M%SZ).md`. `mkdir -p .sous-chef/receipts`
  first, and add `.sous-chef/` to `$(git rev-parse --git-path info/exclude)` if
  it isn't there.
- Every number is measured or carries its method. Worker tokens come from each
  job.log closing "tokens used" summary (uncached input + output, no split) -
  sum across the run's jobs, failed runs included; a log with no token summary
  contributes nothing. Dollar figures come from the [prices.md](prices.md)
  blends and get a `~`. A number you don't have is a line you drop - never a
  guess.

```markdown
# serve: <task one-liner>

- when: <UTC ISO-8601> · wallclock <Xm> (now minus state.md's `started:`)
- worker: <model from the log banners>, <N> runs, <total>k tokens
- cost: ~$<X> API-list terms (blend per prices.md; subscription quota = $0 marginal)
- same tokens at Claude Fable 5 list: ~$<Y> → saved ~$<Z> (conservative -
  measured Fable-only runs spent 0.78-4.3M tokens where the worker spent
  140-361k, per the benchmark in issue #2)
- orchestration overhead: ~<N>×5-7k Claude tokens (~5-7k per delegated run -
  benchmark estimate, not measured)
- diff: <files> files, +<ins>/-<del> (vs the run's baseline)
- verdict: verified | findings unresolved - <which> | halted - <why>

> sous-chef shipped <task> for ~$<X> of <model> (API-list terms). Benchmarked
> 10-20x cheaper than Claude-only - receipts:
> github.com/tomascupr/sous-chef/issues/2
```

The quoted block is the shareable summary, and only a verified run gets one - a
halted or budget-spent receipt keeps its numbers and skips the brag. Keep it
under 280 characters and paste-ready. Its dollar figure is this run's
measurement; its multiple is the published, receipted benchmark - never compute
a per-run multiple (the same-token method yields ~1.7x for gpt-5.5 and ~16x for
GLM-5.2, and the measured counterfactual wasn't run for either). The
"Benchmarked 10-20x" sentence ships only when the worker is a benchmarked one
(per prices.md - the issue-#2 benchmark was measured on gpt-5.5); for an
unbenchmarked worker (the GPT-5.6 tiers, the Sonnet route) drop that sentence
and keep the first. The task line
ships verbatim inside it - client names and private context go with it - so
surface the post for the user to paste; never post anything yourself.

For a simmer, swap the header (`# simmer:`), count laps as runs, and let the
verdict carry the loop outcome (passed lap N of M | budget spent | no progress).
Simmer's lap verdict lines drop job paths, so take worker tokens from this run's
per-lap ledger lines (`~/.sous-chef/ledger.jsonl`, the `"skill":"simmer"`
entries for this repo's laps), the diff from `git diff <loop.md base>..HEAD`
plus the working tree, and wallclock from loop.md's `started:`.
