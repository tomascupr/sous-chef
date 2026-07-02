---
name: mise
description: Mise en place — one-time setup for the sous-chef workflow. Verifies Codex CLI is installed and authenticated, installs the delegation profile, scaffolds AGENTS.md in the current repo, and offers the routing policy for CLAUDE.md. Use when the user asks to set up sous-chef, when /sous-chef:fire fails because Codex or the profile is missing, or in a repo that hasn't been set up yet.
---

# Mise en place — set up the kitchen before service

Run the checks in order. Report each as pass/fixed/needs-user. Never overwrite an existing file without asking.

## 1. Codex CLI present and current

```bash
codex --version
```

- Missing → tell the user: `npm i -g @openai/codex` or `brew install codex`, and stop here.
- Version below 0.134.0 → warn: this plugin uses file-per-profile config (`~/.codex/sous-chef.config.toml`). Older Codex only reads `[profiles.*]` tables from config.toml, which 0.134+ silently ignores — ask the user to upgrade rather than shipping a config that does nothing.

## 2. Auth

```bash
codex login status
```

- Not logged in → ask the user to run `codex login` themselves (it's interactive).
- Check `[ -n "$OPENAI_API_KEY" ]`: if set, note that sous-chef invocations use `env -u OPENAI_API_KEY` so delegated runs bill the ChatGPT subscription, not the API key. If the user prefers API billing, they can remove that prefix in their usage.

## 3. Delegation profile

If `~/.codex/sous-chef.config.toml` does not exist, copy it from the plugin:

```bash
cp "${CLAUDE_PLUGIN_ROOT}/codex/sous-chef.config.toml" ~/.codex/sous-chef.config.toml
```

If it exists, leave it alone and say so. The profile intentionally sets only execution-safety settings (approval policy, sandbox mode, network access) — model and reasoning effort fall through to the user's `~/.codex/config.toml`, which is where they should live. If the user has no model configured there, suggest `model = "gpt-5.5"` and `model_reasoning_effort = "xhigh"` for implementation-grade delegation.

## 4. Repo AGENTS.md — the standing orders

Codex rebuilds its instruction chain from `AGENTS.md` on every run, including non-interactive `codex exec`. That makes it the one place repo standards reach the sous-chef automatically.

- If the current repo has no root `AGENTS.md`: offer to create one from `${CLAUDE_PLUGIN_ROOT}/templates/AGENTS.template.md`, filled in from what you can read in the repo (real build/test/lint commands, real entry points — verify each command exists in package.json/Makefile/pyproject before writing it).
- If `AGENTS.md` exists: leave it.
- Bridge it for Claude: the repo's `CLAUDE.md` should contain the line `@AGENTS.md` so both models read the same standards. Add the line (or create a minimal CLAUDE.md containing it) with the user's OK. A symlink `CLAUDE.md -> AGENTS.md` also works if there's no Claude-specific content.

## 5. GLM-5.2 (optional second implementer)

Ask whether the user wants GLM-5.2 available as an opt-in implementer, and which key
they have:

- **Z.ai coding-plan key (`ZAI_API_KEY`)** → route A, Claude-headless worker:
  `mkdir -p ~/.sous-chef/glm-claude && cp "${CLAUDE_PLUGIN_ROOT}/templates/glm-claude-settings.json" ~/.sous-chef/glm-claude/settings.json`
- **OpenRouter key (`OPENROUTER_API_KEY`)** → route B, Codex profile:
  copy `${CLAUDE_PLUGIN_ROOT}/codex/sous-chef-glm.config.toml` to `~/.codex/` — the
  file is self-contained (it carries its own `[model_providers.openrouter]` block).
- **Neither** → skip; fire stays GPT-5.5-only.

Details and invocations: `${CLAUDE_PLUGIN_ROOT}/skills/fire/references/glm-routes.md`.

## 6. Routing policy (optional, recommended once per machine)

Offer to append the division-of-labor block from `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.routing.md` to the user's `~/.claude/CLAUDE.md` — it's ~10 lines and teaches every future session when to fire and when to cook. Skip if a "sous-chef" section is already there. If the user has no global CLAUDE.md at all, offer `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.global.example.md` as a slim starting point instead.

## 7. Smoke test

```bash
env -u OPENAI_API_KEY codex exec --profile sous-chef --sandbox read-only \
  -c model_reasoning_effort=low "Reply with exactly: MISE OK" 2>/dev/null
```

Expect `MISE OK` in the output. Use `low`, not `minimal` — minimal effort 400s when the
user's config enables tools like `web_search`. On failure, rerun without `2>/dev/null`
and show the error with the likely cause (auth, profile syntax, version).

Finish with a one-screen summary: what passed, what was installed, what the user still needs to do.
