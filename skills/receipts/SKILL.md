---
name: receipts
description: Prints the check - reads .sous-chef/receipts/ and renders the last 10 run receipts as a table with a savings total, and can reprint any receipt's shareable summary. Use when the user asks for receipts, costs, or savings, or invokes /sous-chef:receipts. Receipts are written automatically at the end of every serve and simmer.
---

# Receipts - print the check

Receipts are per-run cost artifacts written by serve and simmer into the current
repo at `.sous-chef/receipts/<utc-timestamp>.md` (ignored via
`.git/info/exclude`, never committed). Each holds the run's measured numbers and
ends with a shareable one-liner. The global ledger (`~/.sous-chef/ledger.jsonl`)
stays the cross-repo running tab; receipts are the per-run, per-repo story.

## Printing the check

Read the last 10 receipts by filename (newest last) and render one table:

| when | task | worker | tokens | ~cost | ~saved vs Fable list | verdict |

Close with one line - "last N runs: ~$X of worker spend, ~$Y saved vs same-token
Fable list." Sum only lines that exist; a receipt missing a number contributes
nothing to that column - say so rather than papering over it.

If the user wants to share one, print that receipt's quoted summary verbatim -
it is written to be pasted unedited.

No `.sous-chef/receipts/` here? Say so - receipts appear after the first serve
or simmer in this repo (a bare fire tabs the ledger, not receipts).

## The files behind it

- [references/receipt-template.md](references/receipt-template.md) - the format
  serve and simmer write, and the honesty rules every number follows.
- [references/prices.md](references/prices.md) - the rough price table (API
  list, dated); edit it when list prices move.
