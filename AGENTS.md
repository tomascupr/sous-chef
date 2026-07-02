# sous-chef

A Claude Code plugin: Claude (Fable 5) orchestrates and reviews, Codex CLI (GPT-5.5)
implements. This repo is the plugin itself - there is no build step and no code to
compile; everything is markdown, JSON, and TOML.

## Map

- `.claude-plugin/` - plugin + marketplace manifests
- `skills/fire|taste|refire|simmer|mise/` - the five skills (each `SKILL.md` + optional `references/`)
- `codex/` - Codex-side profiles shipped to `~/.codex/` (default + GLM-via-OpenRouter)
- `templates/` - files `/mise` scaffolds into user repos and `~/.sous-chef/`
- `docs/design.md` - research receipts behind every design decision

## Working agreements

- Keep SKILL.md bodies short and goal-directed; this plugin targets frontier models -
  no step-by-step scaffolding a strong model doesn't need.
- Every behavioral claim in docs/design.md must carry a source URL. No uncited claims.
- Command examples must use current syntax: file-per-profile Codex config (>= 0.134),
  no `--full-auto`, no `[profiles.*]` tables.
- Match the kitchen register lightly - names and taglines, not forced metaphors in
  instruction text.
