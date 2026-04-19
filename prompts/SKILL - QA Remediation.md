Skill created and registered — visible in the skills list above as qa-remediation.

  What's in it

  - Location: .claude/skills/qa-remediation/SKILL.md (249 lines).
  - Frontmatter: full trigger phrase list; cross-reference to /github-workflow; explicit pushy language for when to use.
  - Body structure:
    a. When to use / when not to use
    b. Comparison table vs /github-workflow (stays on branch, skips PR + Kanban)
    c. 5-step workflow: present → ask → create issues in parallel → atomic fix → push+close → wrap-up
    d. Commit title rules (#N <Capitalised action>, with Conventional Commits alternative)
    e. Overcommit handling, [skip ci], false-positive SKIP rules — all lifted from the project convention
    f. Edge cases (finding turns out wrong, fix grows mid-stream, shared branch, etc.)
    g. Quick reference block + a worked example showing what the opening turn looks like

  Key design choices

  - "All findings get an issue, only selected ones get a fix" is called out as non-negotiable — the skill explicitly tells Claude not to ask whether to open an issue; only whether to fix it.
  - Deferred findings get a ## Deferred section in the issue body so the state is legible to anyone opening the backlog later.
  - Close-after-push-not-batched — the open-issue list then always reflects outstanding work honestly.
  - Severity-ordered with in-bucket ordering heuristic (independent before shared-file).
  - Escape hatches to /github-workflow for anything that turns out to be larger than a single atomic fix.

  Next steps — what would you like?

  1. Ship as-is — the skill is live and will trigger on the phrases in the description.
  2. Description optimisation pass — the skill-creator loop can generate ~20 trigger test queries, let you review them in a browser, then iteratively rewrite the description to hit both "should
  trigger" and "should NOT trigger (goes to /github-workflow instead)". Useful if you want to make sure it doesn't compete poorly with /github-workflow on ambiguous prompts.
  3. Eval loop — run 2-3 realistic review-remediation scenarios (e.g. from the Phase 16 deep-QA) through the skill and compare to the baseline (no skill / only /github-workflow). Measures whether
  Claude actually follows the issue-number-in-commit rule, whether it asks the fix-vs-track question, whether it closes issues after push.

  My recommendation: #2 description optimisation is the highest-leverage next move since the skill overlaps with /github-workflow; a few targeted tweaks to the description would sharpen the
  triggering. Want me to run that loop?