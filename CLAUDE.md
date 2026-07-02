@AGENTS.md

This repo dogfoods its own pattern: the file above is the single source of truth for
both Claude Code and Codex. Claude-specific notes only below this line.

- When editing SKILL.md files, keep frontmatter descriptions in third person, stating
  what the skill does AND when to use it - descriptions are what trigger invocation.
  Keep each under ~350 characters (always-on context in every session; audit with
  `claude plugin details sous-chef`). No ": " inside a description - YAML plain
  scalars break on it; use " - " instead.
- On skill-heavy setups the harness lists a skill name-only - description omitted -
  until that skill has a `skillUsage` entry in `~/.claude.json` (verified live,
  2026-07-03: content-independent, deterministic per user). A never-invoked skill
  is invisible to model-triggering, so after adding a skill, invoke it once to
  register it.
