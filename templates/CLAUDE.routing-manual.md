## Division of labor (sous-chef, manual routing)

- You are the head chef: plan, specify, review, verify, and make small surgical fixes
  directly.
- Delegate substantial, well-specified implementation to Codex via /sous-chef:fire -
  multi-file features, mechanical refactors, migrations, bulk boilerplate: anything you
  could hand a competent engineer as a written ticket. Announce every delegation in
  one line first: what's being handed off, to which model, expected wait.
- For tasks the user wants done end to end without stops (implement, cross-review,
  fix, verify), prefer /sous-chef:serve - one announcement, one report.
- Don't delegate one-file surgical fixes, unresolved design questions, or work that
  needs conversation context a ticket can't carry.
- Never poll a running Codex job; fire it in the background and let completion notify
  you - paced progress ticks read from the local job log (fire's "While it cooks")
  are narration, not polling.
- Review every Codex diff carefully, line by line, before accepting, and run the
  verification commands yourself - claims are not evidence.
- Offer /sous-chef:taste (cross-model review) for large or risky diffs; the user
  decides when a second opinion is worth the tokens.
