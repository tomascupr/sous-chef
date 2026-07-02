---
name: fire
description: Delegates a well-specified implementation task to Codex CLI (GPT-5.5, or opt-in GLM-5.2) running in the background. Use when the user asks to hand work to Codex/GLM, or when an implementation task is substantial and spec-able — multi-file features, mechanical refactors, migrations, bulk boilerplate, test scaffolding. Not for small surgical fixes, ambiguous design work, or anything that needs conversation context that won't fit in a written ticket.
---

# Fire — hand the ticket to the sous-chef

You are the head chef. Codex is your sous-chef: a strong implementer with no memory of this conversation. It executes exactly one written ticket per run. Everything it needs must be on the ticket.

## When to fire vs. cook it yourself

Fire when ALL of these hold:
- The task is implementation, not design — you already know what the end state looks like.
- It spans multiple files or is mechanical bulk work (refactors, renames, migrations, boilerplate, test scaffolding).
- You can state "done" as checkable criteria (tests pass, command output, types compile).

Cook it yourself when ANY of these hold:
- One-file or few-line surgical fix — the delegation round trip costs more than doing it.
- The approach is still ambiguous — resolve design questions first, then fire.
- The task depends on conversation context that can't be written into a ticket.

## Writing the ticket

Write the ticket to a file in your scratchpad directory using the template in [references/ticket-template.md](references/ticket-template.md). The contract is XML-block-structured because Codex follows explicit contracts far better than prose requests:

- `<task>` — the concrete job, with enough repo context to orient a fresh agent.
- `<done_when>` — checkable success criteria. Declarative beats imperative: give success criteria, not step-by-step instructions.
- `<files>` — files/dirs to create or modify, and files/dirs NOT to touch. Without this, Codex will make assumptions.
- `<interfaces>` — exact signatures, types, or API shapes other code depends on.
- `<constraints>` — hard rules (no new dependencies, match existing patterns, etc.).
- `<verification>` — exact commands Codex must run before finishing (test, typecheck, lint).
- `<output_contract>` — what the final message must contain: what changed, what was verified with actual command output, what was left undone and why.
- `<follow_through>` — the default when routine questions come up: keep going, make the reasonable choice, record it; stop only on hard blockers.
- `<action_safety>` — stay narrow; no unrelated refactors; no deleting code it doesn't understand.

Repo-level standards (build commands, conventions, do-not-touch areas) belong in the repo's `AGENTS.md`, which Codex reads automatically on every run — don't duplicate them on the ticket. Run `/sous-chef:mise` once per repo to set that up.

## Choosing the implementer

Default is GPT-5.5 via the `sous-chef` Codex profile. If the user says "with GLM" /
"use GLM" (or has told you to route bulk work there), fire the same ticket at GLM-5.2
instead via whichever route `/sous-chef:mise` configured — see
[references/glm-routes.md](references/glm-routes.md). Never switch models silently;
say which sous-chef is cooking.

## Firing

Run Codex in the background — never in the foreground. Long runs will be killed by the Bash tool's timeout ceiling in the foreground; backgrounded jobs run to completion and you get re-invoked when they exit.

In the snippets below, `$SCRATCHPAD` stands for your session scratchpad/temp directory — substitute its absolute path; it is not a real environment variable.

```
Bash (run_in_background: true):
env -u OPENAI_API_KEY codex exec --profile sous-chef \
  --output-last-message "$SCRATCHPAD/codex-result.md" \
  - < "$SCRATCHPAD/ticket.md" > "$SCRATCHPAD/codex-job.log" 2>&1
```

Notes on the invocation:
- `--profile sous-chef` loads `~/.codex/sous-chef.config.toml` (workspace-write sandbox, approvals never — it never pauses for input that will never arrive). Model and reasoning effort deliberately fall through to the user's `~/.codex/config.toml` defaults.
- `env -u OPENAI_API_KEY` forces subscription auth. If the variable is set, Codex silently bills the API key instead.
- Prompt goes via stdin (`- <`) to avoid shell-quoting damage to the ticket.
- `--output-last-message` writes only the final message to a file; the log gets the progress stream.

## While it cooks

Do NOT poll. Polling loops against a running Codex job are the documented way to incinerate quota while producing nothing. Either:
- End your turn or work on something else — the backgrounded job re-invokes you when it exits; or
- If you must watch for a condition, arm a single Monitor with an until-loop on the job log that matches terminal states (completion AND error signatures), not a poll loop.

## Plating — when the job exits

1. Read `codex-result.md` and run `git status` + `git diff`.
2. Review the diff like a hawk. Codex is a competent implementer that makes wrong assumptions without checking — that is exactly the failure mode you're here to catch.
3. Run the `<verification>` commands yourself. Codex's claims are not evidence; command output is.
4. Then either:
   - Accept — summarize what shipped and what you verified.
   - Send ONE delta instruction on the same thread: `codex exec resume --last - < delta.md` (same background pattern). Send only what changed, not the whole ticket again.

Cap follow-ups at two rounds. If it's still not right after two deltas, take over and finish it yourself — further debate has diminishing returns.

## If Codex is unavailable

If `codex` is missing, unauthenticated, or the profile doesn't exist, say so and offer to run `/sous-chef:mise` — don't silently implement the task yourself without telling the user the delegation failed.
