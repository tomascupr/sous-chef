# GLM-5.2 delegation routes

Two ways to route a fired ticket to GLM-5.2 instead of GPT-5.5. `/sous-chef:mise`
configures one (or both); fire uses whichever is installed. The ticket, the preflight,
the announce-to-user step, and the per-job directory (`$JOB`) are identical to a
normal fire — only the worker invocation changes.

## Route A — Claude Code headless as the GLM worker (coding-plan quota)

Z.ai officially supports Claude Code on the GLM Coding Plan; running it headless with
scoped env gives a full non-interactive surface billing the subscription. Installed
marker: `~/.sous-chef/glm-claude/settings.json` exists. Requires `ZAI_API_KEY` in the
environment.

```
Bash (run_in_background: true), cwd = repo root:
env CLAUDE_CONFIG_DIR="$HOME/.sous-chef/glm-claude" \
    ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY" \
  claude -p --dangerously-skip-permissions \
  < "$JOB/ticket.md" > "$JOB/result.md" 2> "$JOB/job.log"
```

- `claude -p` prints the final message to stdout — so `$JOB/result.md` plays the same
  role as `--output-last-message` does on the Codex route; the progress stream lands
  in `$JOB/job.log`. Plating works unchanged.
- The isolated `CLAUDE_CONFIG_DIR` keeps the worker off your real Anthropic auth and
  global config; its settings.json pins `glm-5.2[1m]` and xhigh effort (which Z.ai's
  devpack docs map to GLM's "max" thinking level).
- Repo standards still reach the worker: it reads the project's `CLAUDE.md`, which
  imports `@AGENTS.md`.
- Honest caveat vs Codex: `--dangerously-skip-permissions` has no OS sandbox
  underneath. Only fire GLM route A inside a repo you'd trust Codex's
  `danger-full-access` in, or on a branch/worktree.

## Route B — Codex with OpenRouter (pay-per-token)

Installed marker: `~/.codex/sous-chef-glm.config.toml` exists (the file is
self-contained — it carries its own provider block). Requires `OPENROUTER_API_KEY`.
Same invocation as the default fire, different profile — the `env -u` prefix is
unnecessary here (OpenRouter authenticates via its own `OPENROUTER_API_KEY`):

```
Bash (run_in_background: true), cwd = repo root:
codex exec --profile sous-chef-glm \
  --output-last-message "$JOB/result.md" \
  - < "$JOB/ticket.md" > "$JOB/job.log" 2>&1
```

Preflight for this route: `test -f ~/.codex/sous-chef-glm.config.toml` — Codex
silently ignores a missing profile and would run under the user's defaults with the
wrong model and no OpenRouter provider.

## Dead ends (do not suggest)

- GLM Coding Plan through Codex CLI: impossible — Codex only speaks the Responses API
  since Feb 2026; Z.ai serves Chat-Completions/Anthropic protocols (error 1214, closed
  as not-planned upstream).
- ZCode (Z.ai's own harness): desktop-only; its bundled CLI was undocumented and
  broken as of v3.1.6, with no headless mode announced since.

## When GLM is worth it

GLM-5.2 slightly out-benchmarks GPT-5.5 on SWE-bench Pro and Terminal-Bench and costs
a fraction per token, but burns ~3.3x the tokens per task and Z.ai uptime can be
spotty. Good fit: bulk mechanical work where cost dominates. Poor fit:
deadline-critical runs.
