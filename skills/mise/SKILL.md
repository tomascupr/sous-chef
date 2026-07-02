---
name: mise
description: Mise en place — one-time setup for the sous-chef workflow. Verifies Codex CLI is installed and authenticated, installs the delegation profile, scaffolds AGENTS.md in the current repo, and offers the routing policy for CLAUDE.md. Use when the user asks to set up sous-chef, when /sous-chef:fire fails because Codex or the profile is missing, or in a repo that hasn't been set up yet.
---

# Mise en place — set up the kitchen before service

Open with the plan so the user knows the shape: "Four checks, at most a couple of
questions, one ~30s smoke test." Run the checks in order, report each as
pass/fixed/needs-user, and **batch any questions into a single AskUserQuestion call**
rather than interrogating one at a time. Never overwrite an existing file without
asking.

## 1. Codex CLI present and current

```bash
codex --version
```

- Missing → offer to install it for the user (`npm i -g @openai/codex` or
  `brew install codex`); if they decline or it fails, stop here and tell them to
  re-run `/sous-chef:mise` after installing.
- Version below 0.134.0 → warn: this plugin uses file-per-profile config
  (`~/.codex/sous-chef.config.toml`). Older Codex only reads `[profiles.*]` tables
  from config.toml, which 0.134+ silently ignores — ask the user to upgrade rather
  than shipping a config that does nothing.

## 2. Auth

```bash
codex login status
```

- Not logged in (exit 1) → tell the user to run `codex login` in a separate terminal
  (it's an interactive browser flow), then re-run `/sous-chef:mise`. **Stop here** —
  the remaining steps end in a smoke test that would fail confusingly without auth.
- Logged in with ChatGPT (the normal, recommended setup — no API key needed): all
  good; delegated runs bill the subscription and tokens auto-refresh, even mid-run.
- Logged in with an API key instead: warn that usage bills at per-token API rates and
  some models available on ChatGPT plans (GPT-5.5 included) may not be available at
  all under API-key auth.
- Check `[ -n "$CODEX_API_KEY" ] || [ -n "$CODEX_ACCESS_TOKEN" ]`: these two env vars
  override the login in `codex exec`, which is why sous-chef invocations unset them —
  mention it if either is set. (`OPENAI_API_KEY` is harmless; current Codex doesn't
  read it for auth.)

## 3. Delegation profile

If `~/.codex/sous-chef.config.toml` does not exist, copy it from the plugin:

```bash
cp "${CLAUDE_PLUGIN_ROOT}/codex/sous-chef.config.toml" ~/.codex/sous-chef.config.toml
```

If it exists, diff it against the plugin's copy: identical → say so and move on;
different → show the diff and ask whether to keep theirs or refresh (this is also the
update path when the plugin ships profile changes). The profile intentionally sets
only execution-safety settings (approval policy, sandbox mode, network access) —
model and reasoning effort fall through to the user's `~/.codex/config.toml`, which
is where they should live. If the user has no model configured there, suggest
`model = "gpt-5.5"` and `model_reasoning_effort = "xhigh"` for implementation-grade
delegation.

## 4. Repo AGENTS.md — the standing orders

Codex rebuilds its instruction chain from `AGENTS.md` on every run, including non-interactive `codex exec`. That makes it the one place repo standards reach the sous-chef automatically.

- If the current repo has no root `AGENTS.md`: offer to create one from `${CLAUDE_PLUGIN_ROOT}/templates/AGENTS.template.md`, filled in from what you can read in the repo (real build/test/lint commands, real entry points — verify each command exists in package.json/Makefile/pyproject before writing it).
- If `AGENTS.md` exists: leave it.
- Bridge it for Claude: the repo's `CLAUDE.md` should contain the line `@AGENTS.md` so both models read the same standards. Add the line (or create a minimal CLAUDE.md containing it) with the user's OK. A symlink `CLAUDE.md -> AGENTS.md` also works if there's no Claude-specific content.
- Note: fire needs a git repo with at least one commit — if this directory isn't one, say so now.

## 5. GLM-5.2 (optional second implementer)

Skip this step silently unless `ZAI_API_KEY` or `OPENROUTER_API_KEY` is set in the
environment, or the user asked about GLM. When it applies:

- **`ZAI_API_KEY` set** → route A, Claude-headless worker: if
  `~/.sous-chef/glm-claude/settings.json` does not exist,
  `mkdir -p ~/.sous-chef/glm-claude && cp "${CLAUDE_PLUGIN_ROOT}/templates/glm-claude-settings.json" ~/.sous-chef/glm-claude/settings.json`;
  if it exists, leave it and say so.
- **`OPENROUTER_API_KEY` set** → route B, Codex profile: if
  `~/.codex/sous-chef-glm.config.toml` does not exist, copy it from
  `${CLAUDE_PLUGIN_ROOT}/codex/` — the file is self-contained (it carries its own
  `[model_providers.openrouter]` block); if it exists, leave it and say so.

Details and invocations: `${CLAUDE_PLUGIN_ROOT}/skills/fire/references/glm-routes.md`.

## 6. Routing policy (optional, recommended once per machine)

Offer to append the division-of-labor block from `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.routing.md` to the user's `~/.claude/CLAUDE.md` — it's ~10 lines and teaches every future session when to fire and when to cook. Skip if a "sous-chef" section is already there. If the user has no global CLAUDE.md at all, offer `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.global.example.md` as a slim starting point instead — its Environment section is placeholder text they must edit to match their machine. If their CLAUDE.md already mandates a pre-commit review or commit gate, point out that simmer makes per-lap checkpoint commits and taste is a second review layer — let them decide how the pieces stack before they collide mid-loop.

## 7. Smoke test

```bash
test -f ~/.codex/sous-chef.config.toml && \
env -u CODEX_API_KEY -u CODEX_ACCESS_TOKEN codex exec --profile sous-chef --skip-git-repo-check \
  -c model_reasoning_effort=low "Reply with exactly: MISE OK" > /tmp/mise-smoke.log 2>&1; \
tail -5 /tmp/mise-smoke.log; grep -m1 'sandbox:' /tmp/mise-smoke.log
```

Success = the output contains `MISE OK` AND the banner's `sandbox:` line says
`workspace-write` — that second check proves the profile actually loaded, because
**Codex silently ignores a missing profile file** and would happily run under the
user's own defaults. Use effort `low`, not `minimal` (minimal 400s when the user's
config enables tools like `web_search`); `--skip-git-repo-check` keeps the test
working outside a git repo. On failure, show the log tail and the likely cause
(auth, profile syntax, version).

Finish with a one-screen summary: what passed, what was installed, what the user still needs to do.
