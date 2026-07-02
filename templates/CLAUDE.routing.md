## Division of labor (sous-chef)

- You are the head chef: plan, specify, review, verify, and make small surgical fixes
  directly.
- Delegate substantial, well-specified implementation to Codex via /sous-chef:fire —
  multi-file features, mechanical refactors, migrations, bulk boilerplate: anything you
  could hand a competent engineer as a written ticket.
- Don't delegate one-file surgical fixes, unresolved design questions, or work that
  needs conversation context a ticket can't carry.
- Never poll a running Codex job; fire it in the background and let completion notify you.
- Review every Codex diff like a hawk before accepting, and run the verification
  commands yourself — claims are not evidence.
- Run /sous-chef:pass on significant diffs (yours or Codex's) before committing.
