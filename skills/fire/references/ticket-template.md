# Ticket template

Fill every section. Delete a section only if it is genuinely empty for this task - an omitted `<files>` or `<done_when>` is how Codex ends up guessing.

```xml
<task>
[What to build/change, in 2-6 sentences. Name the feature, the repo area it lives in,
and any context a fresh engineer would need. State the WHY in one line if it affects
implementation choices.]
</task>

<done_when>
- [Checkable criterion, e.g. "pnpm test passes, including 3 new tests covering X"]
- [Checkable criterion, e.g. "tsc --noEmit reports zero errors"]
- [Checkable criterion, e.g. "GET /api/foo returns 200 with shape {…}"]
</done_when>

<files>
Touch:
- path/to/file.ts - [what changes here]
- path/to/new-file.ts - [create; what goes here]

Do NOT touch:
- [anything else, especially: config, CI, unrelated modules, lockfiles unless required]
</files>

<interfaces>
[Exact signatures/types/API shapes other code depends on. Paste real code, not prose.]
</interfaces>

<constraints>
- Match the existing style and patterns of the surrounding code.
- No new dependencies unless listed here: [none / list]
- [Project-specific hard rules]
<!-- Include the block below ONLY if .sous-chef/86.md has entries; paste them verbatim,
     one per line. Delete this comment and the two lines below it otherwise. -->
- 86'd in this repo - do not reintroduce:
  - [YYYY-MM-DD] <pattern copied from .sous-chef/86.md>
</constraints>

<verification>
Run these before finishing and include their real output in your final message:
- [command 1, e.g. pnpm test]
- [command 2, e.g. pnpm tsc --noEmit]
</verification>

<output_contract>
Your final message must contain exactly three sections:
1. CHANGED - file-by-file summary of what you did.
2. VERIFIED - each verification command with its actual output (trimmed to the
   relevant lines). If a command failed, say so plainly; do not claim success.
3. OPEN - anything left undone, skipped, or discovered along the way, and why.
</output_contract>

<follow_through>
Work until done_when is satisfied. Do not stop to ask routine questions - make the
reasonable choice and record it under OPEN. Stop early only if a hard blocker makes
the task impossible as specified, and say exactly what is missing.
</follow_through>

<action_safety>
Stay narrow. No refactors, cleanups, or "improvements" outside the files listed above.
Do not delete or rewrite code you do not understand - flag it under OPEN instead.
</action_safety>
```
