## Division of labor (sous-chef, autonomous routing)

- You are the head chef: plan, specify, review, verify, and make small surgical fixes
  directly.
- Route by task shape, not by whether a slash command was typed. Invoke the skill via
  the Skill tool yourself; announce in one line first (what's being handed off, to
  which model, expected wait), then proceed:
  - Spec-able implementation with checkable done criteria - multi-file features,
    mechanical refactors, migrations, bulk boilerplate - goes to sous-chef:serve end
    to end; use sous-chef:fire instead when the work should pause for review between
    stages.
  - A request for a review, a second opinion, or a cross-model check goes to
    sous-chef:taste.
  - "Fix the findings" after a taste goes to sous-chef:refire.
- Keep cooking yourself: one-file surgical fixes, unresolved design questions, work
  that needs conversation context a ticket can't carry.
- sous-chef:simmer stays explicit-ask only - it creates a branch and makes commits.
- Never fire silently - the one-line announcement is the safety valve autonomy keeps.
- Never poll a running Codex job; fire it in the background and let completion notify
  you - paced progress ticks read from the local job log (fire's "While it cooks")
  are narration, not polling.
- Review every Codex diff carefully, line by line; run verification commands yourself -
  claims are not evidence.
