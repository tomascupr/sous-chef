# sous-chef

**Fable 5 orchestrates and reviews; GPT-5.5 xhigh implements. Your head chef doesn't chop onions.**

A Claude Code plugin for the two-model kitchen: Claude plans the menu, writes the
ticket, and tastes every plate before it leaves the pass. Codex CLI does the knife
work — in the background, in a sandbox, with no memory of your conversation and no
say over what ships.

## Why run two models

- **Cross-model review catches what self-review can't.** A reviewer from a different
  training lineage doesn't share the author's blind spots — different failure modes
  are the feature. That's also why `/pass` makes Claude validate every finding before
  you see it: the models disagree productively, and validation filters the noise.
- **The cost asymmetry is real.** In one documented delegation setup, Codex did ~20x
  the work of the orchestrating Claude session at ~5–7k tokens of orchestration
  overhead per round trip — and running both mid-tier subscriptions often beats a
  single top-tier one. Spend Claude tokens on judgment — planning, specs, review —
  and Codex tokens on implementation bulk.
- **Specialization matches strengths.** Claude leads where the right action isn't
  obvious before you start; Codex executes well-specified tickets without touching
  adjacent code. The ticket is the interface.

Every design decision is sourced in [docs/design.md](docs/design.md).

## The brigade

| Command | Kitchen | What it does |
|---|---|---|
| `/sous-chef:fire` | Fire the order | Writes a structured ticket (files to touch/not touch, done-when criteria, verification commands) and hands it to `codex exec` in the background. Claude reviews the diff and runs verification itself before accepting. |
| `/sous-chef:pass` | The pass | Cross-model review of your current diff: Codex reviews read-only, then Claude validates every finding against the actual code and filters false positives before you see them. |
| `/sous-chef:simmer` | Reduce until done | A loop, in the loop-engineering sense: Codex implements in fresh iterations; Claude verifies with real commands and judges every lap against a machine-checkable goal. Iteration caps, git checkpoints, no-progress detection, branch-scoped blast radius. |
| `/sous-chef:mise` | Mise en place | One-time setup: checks Codex CLI + auth, installs the delegation profile, scaffolds `AGENTS.md` in your repo, offers the routing policy for your `CLAUDE.md`. |

## Install

```
/plugin marketplace add tomascupr/sous-chef
/plugin install sous-chef@sous-chef
```

Then, inside a repo:

```
/sous-chef:mise
```

Requirements: [Codex CLI](https://developers.openai.com/codex/cli) ≥ 0.134,
authenticated (`codex login` — a ChatGPT subscription is enough; no API key needed).

## How the split works

**Soft routing, not hard blocks.** A routing policy in `CLAUDE.md` plus skills that make
delegation the path of least resistance. Claude still edits directly for small surgical
fixes — hard-blocking Edit/Write provably makes agents route around the block instead
(see the receipts). The boundary that IS hard: delegated Codex runs execute in a
`workspace-write` sandbox with approvals off, and reviews run `read-only`.

**One source of truth for standards.** Repo conventions live in `AGENTS.md`, which
Codex re-reads on every run — including non-interactive `codex exec` — so the
sous-chef gets your standards for free. Claude reads the same file via an `@AGENTS.md`
import in `CLAUDE.md`. Per-task instructions travel on the ticket; standing orders
stay in the file.

**Background always, polling never.** Delegated runs execute via `run_in_background`
so the Bash timeout ceiling can't kill them mid-job, and completion re-invokes Claude.
Polling loops against a running Codex job are the documented way to burn a week of
quota producing nothing.

**Claims are not evidence.** After every delegated run, Claude reviews the diff like a
hawk and re-runs the verification commands itself. Codex saying "tests pass" is a
sentence; `pnpm test` output is a fact.

## What's in the box

```
skills/fire/          delegation skill + ticket template + GLM routes
skills/pass/          cross-review skill + review prompt template
skills/simmer/        loop skill — Codex works, Claude judges, until the goal passes
skills/mise/          setup skill
codex/                Codex profiles → ~/.codex/ (sous-chef default, sous-chef-glm)
templates/            AGENTS.md scaffold, CLAUDE.md routing block, GLM worker settings,
                      example slim global CLAUDE.md
docs/design.md        the receipts: sources for every design decision
```

## FAQ

**Does Claude stop writing code?** No. Small fixes, prototypes, and anything
design-ambiguous stay with Claude. The skill triggers on substantial, spec-able
implementation — the work you'd hand a competent engineer as a written ticket.

**Which models?** Whatever your `~/.codex/config.toml` says — the profile deliberately
pins only sandbox and approval policy. Recommended: `gpt-5.5` at `xhigh` reasoning for
implementation. On the Claude side it's model-agnostic; it was built for and dogfooded
with Fable 5.

**GLM-5.2?** Supported as an opt-in second implementer ("fire with GLM"). It slightly
out-benches GPT-5.5 on SWE-bench Pro and Terminal-Bench at a fraction of the per-token
price (though ~3.3x more token-hungry). Two routes ship as templates: a headless
Claude Code worker on the GLM Coding Plan (officially supported by Z.ai, subscription
quota), or `z-ai/glm-5.2` via OpenRouter through Codex (pay-per-token). `/mise` sets
up whichever key you have. Z.ai's own ZCode harness has no headless mode yet, and the
coding plan can't be used through Codex at all — receipts in
[docs/design.md](docs/design.md).

**Why not MCP?** Plain `codex exec` over Bash gives you the sandbox flag, the exit
code, stdin for prompts, and background execution with no extra moving parts.
Practitioners who tried both consistently landed on the thin wrapper.

**Windows?** The snippets are POSIX; under Claude Code's Git Bash they should work,
but this is dogfooded on macOS — reports welcome.

## Uninstall

`/plugin uninstall sous-chef` removes the skills. If you ran `/mise`, it may also have
created (remove by hand if you're done with them):

- `~/.codex/sous-chef.config.toml` and `~/.codex/sous-chef-glm.config.toml`
- `~/.sous-chef/glm-claude/` (isolated GLM worker config)
- a "Division of labor (sous-chef)" block appended to `~/.claude/CLAUDE.md`
- an `AGENTS.md` scaffold and/or `@AGENTS.md` import line in repos you set up (these
  are yours now — they're useful regardless of the plugin)

## License

MIT © Tomas Cupr
