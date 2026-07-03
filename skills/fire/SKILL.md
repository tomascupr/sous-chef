---
name: fire
description: Delegates a well-specified implementation task to Codex CLI (or opt-in GLM-5.2) in the background. Use when the user asks to hand work to Codex, or for substantial spec-able work - features, refactors, migrations, boilerplate; offer first unless the routing policy is autonomous. Not for small fixes or ambiguous design; never fire silently.
---

# Fire - hand the ticket to the sous-chef

You are the head chef. Codex is your sous-chef: a strong implementer with no memory of this conversation. It executes exactly one written ticket per run. Everything it needs must be on the ticket.

## When to fire vs. cook it yourself

Fire when ALL of these hold:
- The task is implementation, not design - you already know what the end state looks like.
- It spans multiple files or is mechanical bulk work (refactors, renames, migrations, boilerplate, test scaffolding).
- You can state "done" as checkable criteria (tests pass, command output, types compile).

Cook it yourself when ANY of these hold:
- One-file or few-line surgical fix - the delegation round trip costs more than doing it.
- The approach is still ambiguous - resolve design questions first, then fire.
- The task depends on conversation context that can't be written into a ticket.

If the user didn't explicitly ask for delegation, propose it in one line rather than firing silently - delegation sends code to another vendor and spends their quota. Exception - an autonomous routing policy in the user's CLAUDE.md pre-authorizes the delegation; the one-line announcement then replaces the proposal: announce and fire.

## Preflight (all deterministic, run before writing the ticket)

1. **Git repo with at least one commit** - `git rev-parse HEAD` succeeds. Codex refuses non-repos by default, and diff review needs a baseline. If not: tell the user to `git init` / make an initial commit first.
2. **Profile exists** - `test -f ~/.codex/sous-chef.config.toml`. This check is load-bearing: Codex **silently ignores a missing profile** (exit 0, runs under the user's own defaults - possibly no sandbox at all). If missing: stop and offer `/sous-chef:mise`.
3. **Job directory** - mint one per fire: `JOB=$(mktemp -d "$SCRATCHPAD/fire-XXXXXX")` (`$SCRATCHPAD` = your session scratchpad directory; substitute its absolute path). Never share ticket/result/log paths between jobs - concurrent or sequential runs on fixed paths clobber each other and can serve a stale result as a fresh success.
4. **Snapshot the tree** - if `git status --porcelain` is non-empty, warn the user their uncommitted changes will share the tree with Codex's edits (suggest committing/stashing first), and either way save the baseline: `git diff > "$JOB/pre-fire.patch"; git status --short > "$JOB/pre-fire.status"`. At plating you review Codex's delta against this baseline, not the raw diff.

## Writing the ticket

Write the ticket to `$JOB/ticket.md` using the template in [references/ticket-template.md](references/ticket-template.md). The contract is XML-block-structured because Codex follows explicit contracts far better than prose requests:

- `<task>` - the concrete job, with enough repo context to orient a fresh agent.
- `<done_when>` - checkable success criteria. Declarative beats imperative: give success criteria, not step-by-step instructions.
- `<files>` - files/dirs to create or modify, and files/dirs NOT to touch. Without this, Codex will make assumptions.
- `<interfaces>` - exact signatures, types, or API shapes other code depends on.
- `<constraints>` - hard rules (no new dependencies, match existing patterns, etc.).
- `<verification>` - exact commands Codex must run before finishing (test, typecheck, lint).
- `<output_contract>` - what the final message must contain: what changed, what was verified with actual command output, what was left undone and why.
- `<follow_through>` - the default when routine questions come up: keep going, make the reasonable choice, record it; stop only on hard blockers.
- `<action_safety>` - stay narrow; no unrelated refactors; no deleting code it doesn't understand.

Repo-level standards (build commands, conventions, do-not-touch areas) belong in the repo's `AGENTS.md`, which Codex reads automatically on every run - don't duplicate them on the ticket. Run `/sous-chef:mise` once per repo to set that up.

## Firing

Run from the repo root (workspace-write scopes writes to the working directory), in the background - never in the foreground, where the Bash timeout ceiling kills long runs.

```
Bash (run_in_background: true), cwd = repo root:
env -u CODEX_API_KEY -u CODEX_ACCESS_TOKEN codex exec --profile sous-chef \
  --output-last-message "$JOB/result.md" \
  - < "$JOB/ticket.md" > "$JOB/job.log" 2>&1
```

Notes on the invocation:
- `--profile sous-chef` loads `~/.codex/sous-chef.config.toml` (workspace-write sandbox, approvals never - it never pauses for input that will never arrive). Model and reasoning effort deliberately fall through to the user's `~/.codex/config.toml` defaults.
- `env -u CODEX_API_KEY -u CODEX_ACCESS_TOKEN` pins the run to the user's `codex login` (ChatGPT subscription) auth - those two are the only env vars that override it in `codex exec`, and if either is set the run silently bills per-token instead. (`OPENAI_API_KEY` is NOT read for auth by current Codex, and unsetting it would break custom providers that use it as their `env_key`.)
- Prompt goes via stdin (`- <`) to avoid shell-quoting damage to the ticket.

**Then tell the user, in one or two lines:** what was delegated and to which model (read `model` from `~/.codex/config.toml` - don't assert a model you didn't check), that it typically takes 5–20+ minutes at high reasoning effort, where the log lives (`$JOB/job.log`), and that they can cancel anytime.

To route the ticket to GLM-5.2 instead (user opt-in), see [references/glm-routes.md](references/glm-routes.md) - same ticket, different worker invocation.

## While it cooks

Do NOT poll - polling loops against a running Codex job are the documented way to incinerate quota while producing nothing. Work on something else or end your turn; the backgrounded job re-invokes you when it exits. If you must watch for a condition, arm a single Monitor with an until-loop on `$JOB/job.log` matching terminal states (completion AND error signatures like `ERROR:`, `stream disconnected`), not a poll loop.

**If the user cancels:** kill the background task, then run `git status` + `git diff` - the workspace-write worker may have left a half-applied change. Show the user what's there and let them decide keep or revert.

## Plating - when the job exits

1. **Check the outcome before trusting the plate.** If the job exited non-zero, or `$JOB/result.md` is missing or empty, the run failed - read the tail of `$JOB/job.log`, show the user the error verbatim, and offer one rerun or taking over yourself. Two errors worth naming for the user: "You've hit your usage limit" means wait for the plan's 5-hour window to reset (or escalate plans); a persistent `401` means their `codex login` needs redoing. Never present a missing result as a clean outcome. (MCP transport errors near the top of the log are usually harmless noise from the user's Codex-side MCP servers - the real signal is the last lines.)
2. Glance at the log's opening banner: its `sandbox:` line is ground truth for what actually ran. If it isn't `workspace-write`, say so.
3. Read `$JOB/result.md`, then review Codex's actual delta: `git status`/`git diff` compared against `$JOB/pre-fire.patch` - don't attribute the user's own WIP to Codex.
4. Review the diff carefully, line by line. Codex is a competent implementer that makes wrong assumptions without checking - that is exactly the failure mode you're here to catch.
5. Run the `<verification>` commands yourself. Codex's claims are not evidence; command output is.
6. Then either:
   - Accept - summarize what shipped and what you verified.
   - Send ONE delta: a fresh fire (new `$JOB`, short ticket that states what the previous run got wrong, quotes the failing output, and scopes the fix). Do NOT use `codex exec resume` - resumed sessions rebuild config from the user's defaults, silently dropping the sandbox, and `--last` may grab a different session entirely. Fresh run + state on disk is the reliable path.

Cap follow-ups at two rounds. If it's still not right after two deltas, take over and finish it yourself - further debate has diminishing returns.

## If Codex is unavailable

If `codex` is missing, unauthenticated, or the profile doesn't exist (preflight step 2), say so and offer to run `/sous-chef:mise` - don't silently implement the task yourself without telling the user the delegation failed.
