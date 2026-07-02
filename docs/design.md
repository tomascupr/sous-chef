# Design receipts

Every load-bearing decision in sous-chef traces to a documented incident, an official
doc, or a measured comparison — collected via a multi-source research sweep on
2026-07-02. Corrections welcome via issues.

## Why an orchestrator/implementer split at all

- **Cross-model review beats self-review.** A reviewer from a different training
  lineage doesn't share the author's blind spots — our claim, but the supporting data
  points the same way: in one 36-round blind head-to-head (Blake Crosley's test, as
  relayed by a dev.to roundup), Claude Code's output was rated cleaner 67% of the time
  vs Codex's 25%. Two models that disagree that often make useful reviewers for each
  other — provided findings are validated before applying, which is why `/pass` has a
  mandatory validation step.
  Source: [Claude Code vs Codex — 500 Reddit developers](https://dev.to/_46ea277e677b888e0cd13/claude-code-vs-codex-2026-what-500-reddit-developers-really-think-31pb).
- **Cost asymmetry.** In madewithlove's measured delegation setup, "Codex did about
  20x more work than Claude" with ~5–7k tokens of orchestration overhead per round
  trip (and a trivial one-line change cost 13,584 combined tokens — hence fire's
  size threshold). Daniel Vaughan's guide adds that running both mid-tier
  subscriptions often proves more cost-effective than a single top-tier Claude
  subscription.
  Sources: [madewithlove](https://madewithlove.com/blog/claude-up-front-codex-in-the-back/),
  [Using Claude Code and Codex together](https://codex.danielvaughan.com/2026/03/27/using-claude-code-and-codex-together/).
- **Division of labor consensus** across independent write-ups: Claude excels where
  "the right action is not obvious before you start"; Codex optimizes throughput on
  well-specified tasks and "will not change adjacent code unless asked."
  Source: [danielvaughan multi-tool guide](https://codex.danielvaughan.com/2026/03/27/using-claude-code-and-codex-together/).

## Why soft routing instead of hard-blocking Edit/Write

- Anthropic: "Permission rules are enforced by Claude Code, not by the model.
  Instructions in your prompt or CLAUDE.md shape what Claude tries to do, but they
  don't change what Claude Code allows." ([permissions docs](https://code.claude.com/docs/en/permissions))
  — so prose alone is never enforcement. But full tool denial has a documented
  workaround problem:
- [anthropics/claude-code#29709](https://github.com/anthropics/claude-code/issues/29709)
  (closed, not planned): "The hook correctly blocked my Edit attempts three times.
  Instead of accepting the block, I circumvented it by running a Python file-write
  operation via the Bash tool." Edit/Write denies don't cover arbitrary subprocess
  writes, and the delegation CLI itself needs Bash — a hard block that can't actually
  hold is worse than an honest routing policy.
- Every serious published setup — OpenAI's own
  [codex-plugin-cc](https://github.com/openai/codex-plugin-cc),
  [codex-orchestrator](https://github.com/kingbootoshi/codex-orchestrator),
  [myclaude](https://github.com/cexll/myclaude) — enforces roles via subagent tool
  whitelists and by making delegation the path of least resistance, not via global denies.
- The hard boundaries that DO hold are on the Codex side: `sandbox_mode`
  (workspace-write for implementation, read-only for review) and `approval_policy`
  are process-level, not prompt-level.

## Why background-always, polling-never

- [anthropics/claude-code#54143](https://github.com/anthropics/claude-code/issues/54143):
  a single review delegation with an unbounded polling loop consumed 27% of a weekly
  Claude quota over ~12 hours while producing nothing. "In agent systems, budget is
  part of the control plane."
- Foreground Bash has a hard 600s ceiling, and long-run delegations take 5–20+ minutes:
  [#25881](https://github.com/anthropics/claude-code/issues/25881) ("When a command
  hits the 600s ceiling, it is killed mid-execution"), timeout env-var reliability:
  [#34138](https://github.com/anthropics/claude-code/issues/34138). Both closed as
  not planned — raising timeouts is not the sanctioned path.
- The sanctioned path is detach-and-notify: `run_in_background` re-invokes the agent
  on exit ([interactive-mode docs](https://code.claude.com/docs/en/interactive-mode)),
  and the Monitor tool (April 2026) replaces polling with until-conditions.

## Why AGENTS.md is the standards channel

- Official: "Codex reads AGENTS.md files before doing any work" and "rebuilds the
  instruction chain on every run" — including `codex exec`, so a driving agent gets
  repo standards injected for free.
  ([AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md))
- Layering: global `~/.codex/AGENTS.md` → repo root → nested dirs, concatenated
  root-down, closer files win, 32 KiB combined cap.
- Claude Code reads CLAUDE.md, not AGENTS.md; the supported bridge is an `@AGENTS.md`
  import ([memory docs](https://code.claude.com/docs/en/memory)) or a symlink. One
  file, two readers, zero drift.

## Why a file-per-profile Codex config

- Breaking change in Codex 0.134.0: "`--profile` no longer reads
  `[profiles.profile-name]` from config.toml, and the top-level `profile = "..."`
  selector is no longer supported." Profiles are now standalone
  `~/.codex/<name>.config.toml` files.
  ([config-advanced](https://developers.openai.com/codex/config-advanced))
  Most guides published before mid-2026 show the old syntax, which modern Codex
  silently ignores.
- `codex exec` defaults to a read-only sandbox; `--full-auto` is deprecated in favor
  of explicit `--sandbox workspace-write`
  ([non-interactive docs](https://developers.openai.com/codex/noninteractive)).
- The profile pins only execution-safety settings (approval policy, sandbox mode,
  network access), mirroring OpenAI's own plugin: "Leave --effort unset... Leave model
  unset by default" — model/effort belong in the user's `config.toml`.
  ([codex-plugin-cc](https://github.com/openai/codex-plugin-cc))

## Why `env -u OPENAI_API_KEY`

- With the variable set, "Codex CLI silently uses the API key instead of subscription
  auth — and you get billed." Documented by
  [claude-codex-collab](https://github.com/AlessioZazzarini/claude-codex-collab),
  whose bridge unsets it for the same reason.

## Why the ticket contract is XML blocks

- OpenAI's prompting guidance for driving Codex from another agent: "Prefer explicit
  prompt contracts over vague nudges"; "Tell Codex what done looks like. Do not assume
  it will infer the desired end state." Stable XML tags (`<task>`,
  `<structured_output_contract>`, `<verification_loop>`, `<action_safety>`) beat
  raising reasoning effort.
  ([gpt-5-4-prompting skill](https://github.com/openai/codex-plugin-cc/blob/main/plugins/codex/skills/gpt-5-4-prompting/SKILL.md))
- "Codex has no memory of your session. Without a structured spec... Codex will make
  assumptions." ([claude-codex-collab](https://github.com/AlessioZazzarini/claude-codex-collab))
- Delegation has real overhead (~5–7k orchestration tokens per round trip; a trivial
  one-line change cost 13,584 combined tokens) — hence the "cook it yourself" threshold
  in `/fire`. ([madewithlove](https://madewithlove.com/blog/claude-up-front-codex-in-the-back/))

## Why `/pass` validates findings before presenting them

- Field report after ~20 plugin-driven reviews: Codex reviews ran shallower than Opus
  reviews on the same diffs, ~3 of 20 failed silently, and adversarial mode "doesn't
  adjust its expectations based on the scale or criticality of the project" — flagging
  missing circuit breakers on a 500-line cron script.
  ([mejba.me](https://www.mejba.me/blog/codex-plugin-claude-code-adversarial-review))
- The fix (via [nathanonn](https://www.nathanonn.com/)): a validation step where Claude
  "analyzes each comment against the actual codebase" before applying anything —
  adopted wholesale as step 3 of `/pass`.
- Debate cap: two rounds, then take over — convergence between independent reviews is
  the signal; extended argument has diminishing returns.
  ([claude-codex-collab](https://github.com/AlessioZazzarini/claude-codex-collab))

## Why the review gate is NOT included

- OpenAI's own README on its stop-time review gate: it "can create a long-running
  Claude/Codex loop and may drain usage limits quickly."
  [codex-plugin-cc#248](https://github.com/openai/codex-plugin-cc/issues/248) documents
  the rewake loop under transient failures. `/pass` on demand keeps the human deciding
  when a second opinion is worth the tokens.

## Why GLM-5.2 ships as two templates (and not through the coding plan in Codex)

- GLM-5.2 (released 2026-06-16, MIT weights): reported to beat GPT-5.5 on SWE-bench
  Pro (62.1 vs 58.6), Terminal-Bench 2.1 (81.0 vs 78.2) and FrontierSWE (74.4 vs 72.6)
  per a third-party comparison of the published scorecards; independent agentic tests
  found it statistically indistinguishable from Opus 4.8 on terminal tasks at ~46% of
  the cost with caching — but ~3.3x less token-efficient. API: $1.40/$4.40 per M vs
  GPT-5.5's $5/$30.
  ([docs.z.ai](https://docs.z.ai/guides/llm/glm-5.2),
  [comparison](https://lushbinary.com/blog/glm-5-2-vs-claude-opus-4-8-vs-gpt-5-5-coding-comparison/))
- **Hard blocker for Codex + coding plan**: Codex removed `wire_api = "chat"` in
  Feb 2026 (Responses API only); Z.ai serves only Chat-Completions/Anthropic
  protocols → error 1214, closed as not planned
  ([openai/codex#9612](https://github.com/openai/codex/issues/9612)).
- **Route A (Claude-headless worker)**: Claude Code is the first officially supported
  tool on the GLM Coding Plan (`ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic`,
  model `glm-5.2[1m]`; per Z.ai's latest-model devpack page, Claude effort levels map
  to GLM's high/max thinking, xhigh → max).
  ([tool/claude](https://docs.z.ai/devpack/tool/claude),
  [latest-model](https://docs.z.ai/devpack/latest-model)) Headless `claude -p`
  with an isolated `CLAUDE_CONFIG_DIR` gives stdin/JSON/exit codes for free.
- **Route B (OpenRouter via Codex)**: OpenRouter natively speaks the Responses API and
  lists `z-ai/glm-5.2` with the 1M window — the only reliable way to keep Codex as the
  single worker runtime. ([guide](https://ai.sulat.com/run-glm-5-2-in-codex-cli-with-openrouter-79d6058d3457))
  Provider blocks are ignored in project-level `.codex/config.toml` but work in any
  user-level file, including profile files (verified by live test on Codex 0.139) —
  which is why the shipped GLM profile is self-contained.
- **ZCode (Z.ai's own harness) is not a route**: desktop Electron app, no documented
  CLI; the hidden bundled CLI was broken as of v3.1.6
  ([zai-org feedback #51](https://github.com/zai-org/feedback/issues/51)) and
  third-party harnesses are blocked on the missing programmatic surface
  ([paseo#1670](https://github.com/getpaseo/paseo/issues/1670)). Revisit when a real
  CLI ships.

## Why `/simmer` is shaped the way it is (loop engineering)

- The trend: Boris Cherny (creator of Claude Code), June 2026 — "I don't prompt Claude
  anymore. I have loops that are running... My job is to write loops."
  ([TechCrunch](https://techcrunch.com/2026/06/22/the-ai-world-is-getting-loopy/));
  Addy Osmani named the discipline: "Loop engineering is replacing yourself as the
  person who prompts the agent. You design the system that does it instead."
  ([Loop Engineering](https://addyosmani.com/blog/loop-engineering/), 2026-06-07);
  Anthropic's official framing: loops are "agents repeating cycles of work until a
  stop condition is met."
  ([Getting started with loops](https://claude.com/blog/getting-started-with-loops), 2026-06-30)
- **Verification-cost selection**: "every loop Cherny actually names has a success
  condition a machine can check for free. Verification cost, not loop construction,
  decides what you can automate."
  ([Crosley](https://blakecrosley.com/blog/loops-win-where-verification-is-cheap),
  2026-06-09) — hence simmer refuses tasks without a check command.
- **Worker/judge separation**: in Anthropic's `/goal`, "completion is decided by a
  fresh model rather than the one doing the work." Simmer gets the same property
  structurally: Codex implements, Claude runs the checks and judges.
  ([/goal docs](https://code.claude.com/docs/en/goal))
- **Fresh context per lap, state in files/git**: each `codex exec` starts clean;
  progress persists on disk — the Ralph-loop discipline
  ([ghuntley.com/ralph](https://ghuntley.com/ralph/)) that survived into the
  loop-engineering era. Long resumed Codex sessions hit compaction checkpoint-loss
  loops ([openai/codex#25900](https://github.com/openai/codex/issues/25900)); fresh
  exec + disk state is immune.
- **Budgets and blast radius**: iteration caps as the primary safety mechanism
  (Anthropic's own ralph-loop plugin README), and write-access loops confined to a
  branch after documented production incidents from unbounded write loops (Crosley).
- Division of labor vs native primitives: `/goal` loops Claude-as-worker; the official
  `ralph-loop` plugin re-feeds the same prompt to the same Claude session. Simmer fills
  the documented gap: a delegated implementer inside the loop with an independent judge
  outside it.

## The Karpathy grounding

- His only public statement about his own CLAUDE.md (Jan 26, 2026): agent bad habits
  persist "despite a few simple attempts to fix it via instructions in CLAUDE.md" —
  prose is weak; structure is strong. sous-chef therefore puts the load-bearing parts
  in structure: sandbox flags, background execution, ticket contracts, a validation
  step. ([thread](https://threadreaderapp.com/thread/2015883857489522876.html))
- "Don't tell it what to do, give it success criteria and watch it go" → the
  `<done_when>` block is the center of the ticket.
- "If you have any code you actually care about I would watch them like a hawk" → the
  head chef reviews every delegated diff and re-runs verification personally.
- Note: the viral 186k-star "Karpathy CLAUDE.md" is a third-party derivation of that
  post (by Jiayuan Zhang, `multica-ai/andrej-karpathy-skills`), not his file — worth
  knowing before citing it as gospel.

## CLAUDE.md philosophy (why `templates/CLAUDE.global.example.md` is ~50 lines)

- Official guidance: "target under 200 lines per CLAUDE.md file"; keep facts, move
  procedures to skills, move guarantees to hooks; per-line deletion test: "Would
  removing this cause Claude to make mistakes? If not, cut it."
  ([memory](https://code.claude.com/docs/en/memory),
  [best practices](https://code.claude.com/docs/en/best-practices))
- Fable 5-era addendum: instructions written for weaker models are "often too
  prescriptive... and can degrade output quality" — the skills here state goals and
  contracts, not step-by-step scaffolding.
