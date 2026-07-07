# Rough price table - API list, checked 2026-07-06

For receipt estimates only. Job logs report the worker's uncached input + output
combined, with no in/out split, so receipts price tokens at the 50/50 blend
column unless a real split is known. Every dollar figure derived from this table
carries a `~`. Update the numbers and the date together when list prices move -
the as-of date is part of the receipt's honesty.

| Model | In $/MTok | Out $/MTok | 50/50 blend $/MTok | Source |
|---|---|---|---|---|
| gpt-5.5 | 5.00 | 30.00 | 17.50 | https://developers.openai.com/api/docs/pricing |
| claude-fable-5 | 10.00 | 50.00 | 30.00 | https://platform.claude.com/docs/en/about-claude/pricing |
| glm-5.2 (OpenRouter) | ~0.91 | ~2.86 | ~1.89 | https://openrouter.ai/z-ai/glm-5.2 - promo pricing, volatile |

Subscription workers (ChatGPT plan, GLM coding plan) have $0 marginal cost -
receipts therefore always say "API-list terms", never "you paid".
