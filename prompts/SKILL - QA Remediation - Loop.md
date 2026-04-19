I've drafted 20 eval queries (10 should-trigger, 10 should-NOT-trigger) and opened the review HTML in your browser.

  Trigger cases stress scenarios where qa-remediation should win over /github-workflow:
  - Post-review remediation (after /qa-review, /security-review, /ux-review, /ui-polish)
  - Batch of PR review comments to work through
  - "Mix of fix + defer" phrasing (the skill's unique selling point: every finding gets an issue, only some get fixes)
  - Explicit mentions of "remediate", "work through", "address", "apply the review"

  Non-trigger cases (all near-misses — none are trivially irrelevant):
  - Single bug / new feature → should route to /github-workflow
  - "Run /qa-review" → should route to /qa-review itself (producing findings, not consuming them)
  - Single-issue or single-close ops → direct gh call, no skill needed
  - Informational queries (issue count, no-label check) → no workflow at all
  - Planning / PRP writing → /generate-prp
  - "Implement the Phase 16 plan" — fresh implementation from a plan, NOT from review findings → /github-workflow

  Please review the list in your browser. You can:
  - Edit the wording of any query
  - Flip the should-trigger toggle on any entry
  - Add or remove entries
  - Click Export Eval Set when you're done — it will download to ~/Downloads/eval_set.json

  Tell me once the download is in place and I'll kick off the optimisation loop in the background. The loop runs Claude against the eval set 3x per query, iteratively rewrites the description, and
  picks the best version by held-out test score. It takes a few minutes and I'll tail the progress for you.