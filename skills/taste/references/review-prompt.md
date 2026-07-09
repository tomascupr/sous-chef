# Review prompt template

```xml
<task>
Review the following change set in this repository as an independent senior engineer.
Scope: [git working tree | git diff <base>...HEAD | post-fire delta: the changes in
these files: <list>; hunks recorded in <absolute path>/pre-fire.patch predate this
work and are OUT of scope - do not report findings on them]
Focus (if any): [user-provided focus, e.g. "concurrency around the job queue"]
Read the diff AND enough surrounding code to judge it in context. Do not modify anything.
</task>

<grounding_rules>
Ground every finding in code you actually read during this run - cite file and line.
Quote the exact code that is wrong. If a point is an inference rather than something
you verified, label it INFERENCE. Do not report a finding you cannot anchor to a
specific location.
</grounding_rules>

<calibration>
Match your expectations to the scale and criticality of this codebase. A small tool
does not need circuit breakers, observability stacks, or enterprise patterns - do not
flag their absence. Flag only issues that would cause real defects, data loss, security
problems, or maintenance pain in THIS codebase as it exists.
</calibration>

<known_failure_modes>
<!-- Optional - include ONLY if .sous-chef/86.md has entries; paste them verbatim, one
     per line, in place of the placeholder. Delete this whole block otherwise. -->
Known failure modes in this repo, confirmed as defects by past reviews - check the delta
against these first:
- [YYYY-MM-DD] <pattern copied from .sous-chef/86.md>
These bias where you look; they do not lower the bar. Every finding still needs grounding
per <grounding_rules> - do not report one of these unless you can anchor it to a specific
location in the delta under review.
</known_failure_modes>

<structured_output_contract>
Your final message must be exactly:

VERDICT: [SHIP | FIX FIRST] - one-line reason

FINDINGS (ordered most severe first; empty section if none):
For each finding:
- [severity: blocker|major|minor] file:line - one-sentence defect statement
  EVIDENCE: the quoted code and why it fails; concrete inputs/state -> wrong outcome
  FIX: the minimal change that resolves it

Do not pad. Zero findings with a SHIP verdict is a valid and useful result.
</structured_output_contract>
```

## Adversarial addendum - production-critical code only

Append inside `<task>` when reviewing auth, payments, data storage, or external API boundaries:

```
Additionally, challenge the approach itself: what assumptions does this design depend
on, and under what real-world conditions do they break? Actively try to construct a
concrete exploit or failure sequence for the security- and data-integrity-relevant
paths. Report only attacks you can trace through the actual code.
```
