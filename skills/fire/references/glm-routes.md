# Alternate worker delegation routes

Ways to route a fired ticket to a worker other than the default GPT-5.5:
two GLM-5.2 routes, and a no-extra-key Claude route (Sonnet 5). `/sous-chef:mise`
configures one (or both); fire uses whichever is installed. The ticket, the
announce-to-user step, and the per-job directory (`$JOB`) are identical to a
normal fire - the worker invocation changes, and preflight is route-specific
(listed under each route; Codex's profile check applies to the default route
only).

The Bash tool's `run_in_background: true` is still the only backgrounding: do not add
`&`, `nohup`, or `disown` inside either command, or the harness can report false
completion while the worker keeps running.

## Route A - Claude Code headless as the GLM worker (coding-plan quota)

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

- `claude -p` prints the final message to stdout - so `$JOB/result.md` plays the same
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

## Route B - Codex with OpenRouter (pay-per-token)

Installed marker: `~/.codex/sous-chef-glm.config.toml` exists (the file is
self-contained - it carries its own provider block). Requires `OPENROUTER_API_KEY`.
Same invocation as the default fire, different profile - the `env -u` prefix is
unnecessary here (OpenRouter authenticates via its own `OPENROUTER_API_KEY`):

```
Bash (run_in_background: true), cwd = repo root:
codex exec --profile sous-chef-glm \
  --output-last-message "$JOB/result.md" \
  - < "$JOB/ticket.md" > "$JOB/job.log" 2>&1
```

Preflight for this route: `test -f ~/.codex/sous-chef-glm.config.toml` - Codex
silently ignores a missing profile and would run under the user's defaults with the
wrong model and no OpenRouter provider.

## Route C - Claude subscription worker (Sonnet 5, no extra key)

Fire the ticket to Claude Code headless on the user's own Anthropic
subscription - no new key, no provider config. This is the fallback worker
for Codex users when Codex hits its usage limit mid-serve ("try again at
HH:MM"); mise and taste still need Codex, so it is not a Codex-free
configuration on its own. Installed marker: none needed - `claude` is
already on the machine running this plugin.

Preflight for this route: `command -v claude` - no Codex profile check;
fire's step-2 hard stop applies to the default route only.

```
Bash (run_in_background: true), cwd = repo root:
claude -p --model claude-sonnet-5 --dangerously-skip-permissions --strict-mcp-config \
  < "$JOB/ticket.md" > "$JOB/result.md" 2> "$JOB/job.log"
```

- Same plating as route A: `claude -p` prints the final message to stdout, so
  `$JOB/result.md` plays the `--output-last-message` role. `$JOB/job.log` is
  errors-only (`claude -p` streams no progress to stderr) - progress ticks
  should report elapsed time, not log contents.
- Uses the default `CLAUDE_CONFIG_DIR`, so the worker inherits the user's
  subscription auth (OAuth/keychain) with zero setup - it runs on the real
  config dir. `--strict-mcp-config` keeps global MCP servers out, but
  global hooks and plugins still load, and so does the user's global
  `CLAUDE.md` - including this plugin's routing block - so **open the
  ticket with "Implement directly; do not delegate."** to keep the worker
  from contemplating recursion. (`--bare` is not an option - it never
  reads OAuth/keychain.)
- Quota is shared with the orchestrator (one Anthropic subscription), but
  Sonnet 5 drains it far slower than Opus/Fable-tier orchestration does.
- Cross-model review: when Codex quota recovers, keep Codex as the taster -
  Sonnet implements, GPT-5.5 reviews, the head chef orchestrates. If both
  worker and reviewer are Anthropic models, say so in the report (the
  cross-lineage value of the taste is reduced).
- Honest caveat, same as route A: `--dangerously-skip-permissions` has no OS
  sandbox underneath. Only fire route C inside a repo you'd trust Codex's
  `danger-full-access` in, or on a branch/worktree.
- No ledger line - `claude -p` emits no token summary (same gap as
  Route A).
- Invocation spelling: `/sous-chef:fire --with sonnet <task>` (or the loose
  phrase "fire with sonnet").

## Dead ends (do not suggest)

- GLM Coding Plan through Codex CLI: impossible - Codex only speaks the Responses API
  since Feb 2026; Z.ai serves Chat-Completions/Anthropic protocols (error 1214, closed
  as not-planned upstream).
- ZCode (Z.ai's own harness): desktop-only; its bundled CLI was undocumented and
  broken as of v3.1.6, with no headless mode announced since.

## When GLM is worth it

GLM-5.2 slightly out-benchmarks GPT-5.5 on SWE-bench Pro and Terminal-Bench and costs
a fraction per token, but burns ~3.3x the tokens per task and Z.ai uptime can be
spotty. Good fit: bulk mechanical work where cost dominates. Poor fit:
deadline-critical runs.
