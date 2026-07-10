# Rough price table - API list, checked 2026-07-10

For receipt estimates only. Job logs report the worker's uncached input + output
combined, with no in/out split, so receipts price tokens at the 50/50 blend
column unless a real split is known. Every dollar figure derived from this table
carries a `~`. Update the numbers and the date together when list prices move -
the as-of date is part of the receipt's honesty.

| Model | In $/MTok | Out $/MTok | 50/50 blend $/MTok | Source |
|---|---|---|---|---|
| gpt-5.6-sol | 5.00 | 30.00 | 17.50 | https://developers.openai.com/api/docs/pricing |
| gpt-5.6-terra | 2.50 | 15.00 | 8.75 | https://developers.openai.com/api/docs/pricing |
| gpt-5.6-luna | 1.00 | 6.00 | 3.50 | https://developers.openai.com/api/docs/pricing |
| gpt-5.5 | 5.00 | 30.00 | 17.50 | https://developers.openai.com/api/docs/pricing |
| claude-fable-5 | 10.00 | 50.00 | 30.00 | https://platform.claude.com/docs/en/about-claude/pricing |
| claude-sonnet-5 | 3.00 | 15.00 | 9.00 | https://platform.claude.com/docs/en/about-claude/pricing - intro 2.00/10.00 through 2026-08-31 |
| glm-5.2 (OpenRouter) | ~0.91 | ~2.86 | ~1.89 | https://openrouter.ai/z-ai/glm-5.2 - promo pricing, volatile |

Subscription workers (ChatGPT plan, Claude plan, GLM coding plan) have $0
marginal cost - receipts therefore always say "API-list terms", never "you
paid". The receipt's quoted "Benchmarked 10-20x" line only fires for
benchmarked workers; workers without a published benchmark comparison (e.g.
the Sonnet 5 route, the GPT-5.6 tiers) omit it - the issue-#2 benchmark was
measured on gpt-5.5.
