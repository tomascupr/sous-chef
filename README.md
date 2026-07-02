# sous-chef

![MIT](https://img.shields.io/badge/license-MIT-blue) ![Claude Code plugin](https://img.shields.io/badge/Claude_Code-plugin-d97757) ![Codex CLI ≥ 0.134](https://img.shields.io/badge/Codex_CLI-%E2%89%A50.134-black)

**Fable 5 orchestrates and reviews; GPT-5.5 xhigh implements. Your head chef doesn't chop onions.**

A Claude Code plugin for the two-model kitchen: Claude plans the menu, writes the
ticket, and tastes every plate before it leaves the kitchen. Codex CLI (GPT-5.5 at
max reasoning; GLM-5.2 opt-in) does the knife work — in a sandbox, in the background,
with no say over what ships. Spend Claude tokens on judgment and Codex tokens on bulk:
in the measured setup this pattern is built on, [Codex did ~20x the implementation
work](https://madewithlove.com/blog/claude-up-front-codex-in-the-back/) per
orchestration round trip, and two mid-tier subscriptions often beat one top-tier one.

## What it looks like

```text
> /sous-chef:fire migrate the auth module off the deprecated session API

Claude   writes the ticket — files to touch, files NOT to touch, done-when
         criteria, verification commands
Claude   "Firing at gpt-5.5: auth migration, ~10-20 min, log at …/job.log —
         say the word to cancel." (background; you keep working)
Codex    implements. 11 files changed. Claims "all tests pass."
Claude   reviews the diff line by line, re-runs pnpm test + tsc itself
Claude   catches it: middleware change has no test coverage despite the claim.
         Fires one delta ticket.
Claude   second diff verified — 42 tests pass, types clean. Accepted.
```

Codex saying "tests pass" is a sentence; `pnpm test` output is a fact.

## The brigade

| Command | Kitchen term | What it does |
|---|---|---|
| `/sous-chef:fire` | Fire the order (start cooking it) | Writes a structured ticket and hands it to `codex exec` in the background. Claude announces the handoff, reviews the diff against a pre-fire baseline, and re-runs verification itself before accepting. |
| `/sous-chef:taste` | The chef tastes every plate | Cross-model review of your current diff: Codex reviews read-only, then Claude validates every finding against the actual code and filters false positives before you see them. On-demand — you decide when a second opinion is worth the tokens. |
| `/sous-chef:simmer` | Reduce (simmer down) until done | An implement-verify loop: Codex works in fresh iterations on a dedicated branch; Claude runs the checks and judges every lap against a machine-checkable goal. Lap caps, git checkpoints, no-progress detection. |
| `/sous-chef:mise` | Mise en place (prep before service) | Setup: checks Codex CLI + auth, installs the delegation profile, scaffolds `AGENTS.md` in your repo, offers the routing policy for your `CLAUDE.md`. |

## Install

Requirements first: [Codex CLI](https://developers.openai.com/codex/cli) ≥ 0.134,
authenticated (`codex login` — a ChatGPT subscription is enough; no API key needed).

```text
/plugin marketplace add tomascupr/sous-chef
/plugin install sous-chef@sous-chef
```

(`sous-chef@sous-chef` is `plugin@marketplace` — same name for both here.) Then,
inside a repo:

```text
/sous-chef:mise
```

## How the split works

```text
you ── "/fire: migrate the auth module" ──▶ CLAUDE (head chef)
                                              │ ticket: files ±, done-when,
                                              │ verification commands
                                              ▼
            ┌────────────────────────────────────────────┐
            │ codex exec --profile sous-chef             │  background;
            │ workspace-write sandbox · approvals off    │  no session memory;
            │ reads AGENTS.md · implements the ticket    │  hard boundary
            └───────────────────┬────────────────────────┘
                                ▼ diff
            CLAUDE reviews the diff + re-runs verification itself
                   │                        │
               accept ✓          one delta ticket, max two rounds,
                                 then take over
```

**Soft routing, not hard blocks.** A routing policy in `CLAUDE.md` plus skills that make
delegation the path of least resistance. Claude still edits directly for small surgical
fixes — hard-blocking Edit/Write provably makes agents route around the block instead.
The boundary that IS hard: delegated Codex runs execute in a `workspace-write` sandbox
with approvals off, and reviews run `read-only`.

**One source of truth for standards.** Repo conventions live in `AGENTS.md`, which
Codex re-reads on every run — including non-interactive `codex exec` — so the
sous-chef gets your standards for free. Claude reads the same file via an `@AGENTS.md`
import in `CLAUDE.md`. Per-task instructions travel on the ticket; standing orders
stay in the file.

**Background always, polling never.** Delegated runs execute via `run_in_background`
so the Bash timeout ceiling can't kill them mid-job, and completion re-invokes Claude.

**Claims are not evidence.** After every delegated run, Claude reviews the diff line
by line and re-runs the verification commands itself.

## The receipts

Every load-bearing decision traces to a documented incident, an official doc, or a
measured comparison — not vibes. A sample:

- **Why background-always:** a single polling loop against a running Codex job burned
  27% of a weekly Claude quota in ~12 hours producing nothing
  ([anthropics/claude-code#54143](https://github.com/anthropics/claude-code/issues/54143)).
- **Why soft routing, not blocking Edit/Write:** an agent, blocked three times by a
  hook, routed around it with a Python file-write via Bash
  ([anthropics/claude-code#29709](https://github.com/anthropics/claude-code/issues/29709)).
  A hard block that can't hold is worse than an honest routing policy.
- **Why findings get validated:** in a 20-review field test, ~3 of 20 Codex reviews
  failed silently, and adversarial mode flagged missing circuit breakers on a
  500-line cron script.

Full sources for these and every other decision: [docs/design.md](docs/design.md).

## What's in the box

```text
skills/fire/          delegation skill + ticket template + GLM routes
skills/taste/         cross-review skill + review prompt template
skills/simmer/        loop skill — Codex works, Claude judges, until the goal passes
skills/mise/          setup skill
codex/                Codex profiles → ~/.codex/ (sous-chef default, sous-chef-glm)
templates/            AGENTS.md scaffold, CLAUDE.md routing block, GLM worker config
docs/design.md        the receipts: sources for every design decision
```

## FAQ

**How is this different from OpenAI's official codex plugin?** Three deliberate
divergences, each with receipts in [docs/design.md](docs/design.md): (1) no stop-time
review gate — OpenAI's own README warns it "can create a long-running Claude/Codex
loop and may drain usage limits quickly"; `/taste` runs on demand, so a human decides
when a second opinion is worth the tokens. (2) `/taste` validates every Codex finding
against the actual code before you see it — raw cross-model reviews over-flag, and
validation filters the false positives. (3) `/simmer` fills a gap neither the official
plugin nor ralph-loop covers: a delegated implementer inside the loop with an
independent judge outside it.

**What does this cost me?** Two subscriptions: any Claude plan for Claude Code, and a
ChatGPT plan for Codex — `codex login`, no API key needed. Subscription auth is the
first-class path for headless runs: `codex exec` reuses the saved login, tokens
auto-refresh even mid-run, and fire unsets the two env vars (`CODEX_API_KEY`,
`CODEX_ACCESS_TOKEN`) that could silently switch a run to per-token billing.
Delegation overhead is ~5–7k Claude tokens per round trip, which is why `/fire`
refuses tasks small enough to cook directly.

**What do I see while it cooks?** When Claude fires, it tells you what was delegated,
the expected duration (typically 5–20+ minutes at high reasoning effort), and the log
path. You keep working; Claude is re-invoked when the job exits. You can cancel
anytime — Claude kills the job and shows you any partial changes so you decide keep
or revert.

**Does Claude stop writing code?** No. Small fixes, prototypes, and anything
design-ambiguous stay with Claude. Fire triggers on substantial, spec-able
implementation — the work you'd hand a competent engineer as a written ticket — and
announces the handoff rather than delegating silently.

**Which models?** Whatever your `~/.codex/config.toml` says — the profile deliberately
pins only sandbox and approval policy. Recommended: `gpt-5.5` with
`model_reasoning_effort = "xhigh"`. On the Claude side it's model-agnostic; it was
built for and dogfooded with Fable 5.

**GLM-5.2?** Supported as an opt-in second implementer ("fire with GLM"). It slightly
out-benchmarks GPT-5.5 on SWE-bench Pro and Terminal-Bench at a fraction of the
per-token price, though ~3.3x more token-hungry. Two routes ship as templates —
a headless Claude Code worker on the GLM Coding Plan, or OpenRouter through Codex —
and `/mise` sets up whichever key you have. Details and dead ends:
[docs/design.md](docs/design.md).

**Why not MCP?** Plain `codex exec` over Bash gives you the sandbox flag, the exit
code, stdin for prompts, and background execution with no extra moving parts.
Practitioners who tried both consistently landed on the thin wrapper.

**Windows?** The snippets are POSIX; under Claude Code's Git Bash they should work,
but this is dogfooded on macOS.

## Uninstall

`/plugin uninstall sous-chef` removes the skills (and
`/plugin marketplace remove sous-chef` the registration). If you ran `/mise`, it may
also have created (remove by hand if you're done with them):

- `~/.codex/sous-chef.config.toml` and `~/.codex/sous-chef-glm.config.toml`
- `~/.sous-chef/glm-claude/` (isolated GLM worker config)
- a "Division of labor (sous-chef)" block appended to `~/.claude/CLAUDE.md`
- an `AGENTS.md` scaffold and/or `@AGENTS.md` import line in repos you set up (these
  are yours now — they're useful regardless of the plugin)

## Contributing

Field reports welcome — especially Windows, and especially receipts that contradict
[docs/design.md](docs/design.md); it's meant to be corrected.

## License

MIT © Tomas Cupr
