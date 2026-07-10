---
name: mise
description: Mise en place - setup and health check. Verifies Codex CLI and auth, installs the delegation profile, scaffolds AGENTS.md, and offers the routing policy. Re-run anytime, and after plugin updates to refresh the profile. Use when the user asks to set up sous-chef, or when another sous-chef skill fails because Codex or the profile is missing.
---

# Mise en place - set up the kitchen before service

Every other skill assumes a chain: CLI → auth → profile → repo standards → routing
policy, proven by a smoke test. Mise walks that chain and makes each link true.
Open with the plan so the user knows the shape: "Four checks, at most a couple of
questions, one ~30s smoke test." Report each check as pass/fixed/needs-user, **batch
any questions into a single AskUserQuestion call** rather than interrogating one at
a time, and never overwrite an existing file without asking.

## 1. Codex CLI present and current

```bash
codex --version
```

- Missing → offer to install it for the user (`npm i -g @openai/codex` or
  `brew install codex`); if they decline or it fails, stop here and tell them to
  re-run `/sous-chef:mise` after installing.
- Version below 0.134.0 → warn: this plugin uses file-per-profile config
  (`~/.codex/sous-chef.config.toml`). Older Codex only reads `[profiles.*]` tables
  from config.toml, which 0.134+ silently ignores - ask the user to upgrade rather
  than shipping a config that does nothing.

## 2. Auth

```bash
codex login status
```

- Not logged in (exit 1) → tell the user to run `codex login` in a separate terminal
  (it's an interactive browser flow), then re-run `/sous-chef:mise`. **Stop here** -
  the remaining steps end in a smoke test that would fail confusingly without auth.
- Logged in with ChatGPT (the normal, recommended setup - no API key needed): all
  good; delegated runs bill the subscription and tokens auto-refresh, even mid-run.
- Logged in with an API key instead: warn that usage bills at per-token API rates and
  some models available on ChatGPT plans (GPT-5.5 included) may not be available at
  all under API-key auth.
- Check `[ -n "$CODEX_API_KEY" ] || [ -n "$CODEX_ACCESS_TOKEN" ]`: these two env vars
  override the login in `codex exec`, which is why sous-chef invocations unset them -
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
only execution-safety settings (approval policy, sandbox mode, network access) -
model and reasoning effort fall through to the user's `~/.codex/config.toml`, which
is where they should live. If the user has no model configured there, suggest
`model = "gpt-5.6-sol"` and `model_reasoning_effort = "high"` for implementation-grade
delegation (`gpt-5.6-terra` for 5.5-class output at half the API-list price). If
their config enables 5.6's ultra mode, warn that it multiplies token spend by design
and should stay off for delegated background runs.

Also check `~/.codex/config.toml` for `service_tier = "fast"`. Fast mode flows into
delegated background runs and burns credits at 2.5x (GPT-5.5) for a 1.5x speedup -
paying double on a shared quota for latency a background run mostly doesn't need.
If set, say so and offer to add `service_tier = "default"` to the sous-chef profile
(there's a commented line ready in the file); their interactive sessions stay fast
either way. Fold this into the batched question round.

## 4. Repo AGENTS.md - the standing orders

Codex rebuilds its instruction chain from `AGENTS.md` on every run, including non-interactive `codex exec`. That makes it the one place repo standards reach the sous-chef automatically.

- If the current repo has no root `AGENTS.md`: offer to create one from `${CLAUDE_PLUGIN_ROOT}/templates/AGENTS.template.md`, filled in from what you can read in the repo (real build/test/lint commands, real entry points - verify each command exists in package.json/Makefile/pyproject before writing it).
- If `AGENTS.md` exists: leave it.
- Bridge it for Claude: the repo's `CLAUDE.md` should contain the line `@AGENTS.md` so both models read the same standards. Add the line (or create a minimal CLAUDE.md containing it) with the user's OK. A symlink `CLAUDE.md -> AGENTS.md` also works if there's no Claude-specific content.
- Note: fire needs a git repo with at least one commit - if this directory isn't one, say so now.

## 5. Alternate workers (optional second implementer)

**Claude Sonnet 5 route (no setup):** nothing to install - `claude -p --model
claude-sonnet-5` on the user's own subscription is always available as a
fallback worker (see fire's `references/glm-routes.md`, Route C). Mention it
only if the user asks, or when Codex auth/quota is the reason mise was re-run.

**GLM-5.2:** skip silently unless `ZAI_API_KEY` or `OPENROUTER_API_KEY` is set in the
environment, or the user asked about GLM. When it applies:

- **`ZAI_API_KEY` set** → route A, Claude-headless worker: if
  `~/.sous-chef/glm-claude/settings.json` does not exist,
  `mkdir -p ~/.sous-chef/glm-claude && cp "${CLAUDE_PLUGIN_ROOT}/templates/glm-claude-settings.json" ~/.sous-chef/glm-claude/settings.json`;
  if it exists, leave it and say so.
- **`OPENROUTER_API_KEY` set** → route B, Codex profile: if
  `~/.codex/sous-chef-glm.config.toml` does not exist, copy it from
  `${CLAUDE_PLUGIN_ROOT}/codex/` - the file is self-contained (it carries its own
  `[model_providers.openrouter]` block); if it exists, leave it and say so.

Details and invocations: `${CLAUDE_PLUGIN_ROOT}/skills/fire/references/glm-routes.md`.

## 6. Routing policy (pick a mode, once per machine)

Detection first: if `~/.claude/CLAUDE.md` exists, grep it for
`Division of labor (sous-chef`. A heading with `manual routing` is manual, a heading
with `autonomous routing` is autonomous, and a heading with no mode suffix is legacy
manual. If a block exists, say which mode is installed and offer to switch by replacing
that block with the other template; never append a duplicate. If the user declines,
leave it.

If no block exists, fold one routing question into the existing batched
AskUserQuestion round:
- Manual (recommended) - skills run when the user invokes them or accepts a one-line
  offer; today's behavior.
- Autonomous - Claude routes task-shaped work to serve/fire/taste/refire itself by
  invoking the Skill tool, announcing in one line first; simmer stays explicit-ask.
- Skip.

Manual appends `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.routing-manual.md`; autonomous
appends `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.routing-auto.md`. If the user has no
global `CLAUDE.md` at all, offer `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.global.example.md`
as the slim starting point - and if the pick was autonomous, swap its manual routing
block for the autonomous template so the installed mode matches the answer. Its
Environment section is placeholder text they must edit to match their machine.

If the autonomous block was installed, run the follow-ups:
- Ask before adding `Bash(env -u CODEX_API_KEY -u CODEX_ACCESS_TOKEN codex exec*)` to
  `permissions.allow` in `~/.claude/settings.json`, creating the file/key if absent.
  Permission prompts still gate delegated runs; without this rule, autonomous routing
  stops at a dialog on the first fire - noisier, not broken.
- Read-only check `~/.claude.json` for `skillUsage` entries for the four skills
  autonomous routing self-triggers - `sous-chef:serve`, `sous-chef:fire`,
  `sous-chef:taste`, `sous-chef:refire`. Report any missing entries and tell the
  user each missing skill needs one manual invocation to register. Never write
  `~/.claude.json`.

If their `CLAUDE.md` already mandates a pre-commit review or commit gate, point out
that simmer makes per-lap checkpoint commits and taste is a second review layer - let
them decide how the pieces stack before they collide mid-loop.

## 7. Smoke test

```bash
SMOKE="$SCRATCHPAD/mise-smoke.log"  # $SCRATCHPAD = your session scratchpad directory - substitute its absolute path
test -f ~/.codex/sous-chef.config.toml && \
env -u CODEX_API_KEY -u CODEX_ACCESS_TOKEN codex exec --profile sous-chef --skip-git-repo-check \
  -c model_reasoning_effort=low "Reply with exactly: MISE OK" > "$SMOKE" 2>&1; \
tail -5 "$SMOKE"; grep -m1 'model:' "$SMOKE"; grep -m1 'sandbox:' "$SMOKE"
```

Success = the output contains `MISE OK` AND the banner's `sandbox:` line says
`workspace-write` - that second check proves the profile actually loaded, because
**Codex silently ignores a missing profile file** and would happily run under the
user's own defaults. Use effort `low`, not `minimal` (minimal 400s when the user's
config enables tools like `web_search`); `--skip-git-repo-check` keeps the test
working outside a git repo. On failure, show the log tail and the likely cause
(auth, profile syntax, version).

Finish with a one-screen summary: what passed, what was installed, which model and effort delegated runs will use (the banner's `model:` line is ground truth for the model; effort falls through to `~/.codex/config.toml` - the smoke test pins its own to low), and what the user still needs to do. If `~/.sous-chef/ledger.jsonl` exists, close with the running tab - `jq -s '{jobs: length, tokens: (map(.tokens) | add)}' ~/.sous-chef/ledger.jsonl` - delegated jobs to date and the tokens they kept off Claude.
