# GLM-5.2 delegation routes

Two ways to route a fired ticket to GLM-5.2 instead of GPT-5.5. `/sous-chef:mise`
configures one (or both); fire uses whichever is installed. The ticket is identical —
only the worker invocation changes. As in the fire skill, `$SCRATCHPAD` stands for
your session scratchpad directory — substitute its absolute path.

## Route A — Claude Code headless as the GLM worker (coding-plan quota)

Z.ai officially supports Claude Code on the GLM Coding Plan; running it headless with
scoped env gives a full non-interactive surface billing the subscription. Installed
marker: `~/.sous-chef/glm-claude/settings.json` exists. Requires `ZAI_API_KEY` in the
environment.

```
Bash (run_in_background: true):
env CLAUDE_CONFIG_DIR="$HOME/.sous-chef/glm-claude" \
    ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY" \
  claude -p --dangerously-skip-permissions \
  < "$SCRATCHPAD/ticket.md" > "$SCRATCHPAD/glm-job.log" 2>&1
```

- The isolated `CLAUDE_CONFIG_DIR` keeps the worker off your real Anthropic auth and
  global config; its settings.json pins `glm-5.2[1m]` and xhigh effort (which Z.ai's
  devpack docs map to GLM's "max" thinking level).
- Repo standards still reach the worker: it reads the project's `CLAUDE.md`, which
  imports `@AGENTS.md`.
- Honest caveat vs Codex: `--dangerously-skip-permissions` has no OS sandbox
  underneath. Only fire GLM route A inside a repo you'd trust Codex's
  `danger-full-access` in, or on a branch/worktree.

## Route B — Codex with OpenRouter (pay-per-token)

Installed marker: `~/.codex/sous-chef-glm.config.toml` exists AND
`[model_providers.openrouter]` is present in `~/.codex/config.toml`. Requires
`OPENROUTER_API_KEY`. Same invocation as the default fire, different profile — and do
NOT unset OPENAI_API_KEY-style vars here; OpenRouter needs its key:

```
Bash (run_in_background: true):
codex exec --profile sous-chef-glm \
  --output-last-message "$SCRATCHPAD/codex-result.md" \
  - < "$SCRATCHPAD/ticket.md" > "$SCRATCHPAD/codex-job.log" 2>&1
```

## Dead ends (do not suggest)

- GLM Coding Plan through Codex CLI: impossible — Codex only speaks the Responses API
  since Feb 2026; Z.ai serves Chat-Completions/Anthropic protocols (error 1214, closed
  as not-planned upstream).
- ZCode (Z.ai's own harness): desktop-only; its bundled CLI was undocumented and
  broken as of v3.1.6, with no headless mode announced since.

## When GLM is worth it

GLM-5.2 slightly out-benches GPT-5.5 on SWE-bench Pro and Terminal-Bench and costs a
fraction per token, but burns ~3.3x the tokens per task and Z.ai uptime can be spotty.
Good fit: bulk mechanical work where cost dominates. Poor fit: deadline-critical runs.
