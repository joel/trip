Rename landed in commit 0606a71.

  Summary

  ┌─────────────────────────────┬──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │           Change            │                                                                             Details                                                                              │
  ├─────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ Skill directory             │ .claude/skills/github-workflow/ → .claude/skills/execution-plan/ (git mv, git preserves history)                                                                 │
  ├─────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ Frontmatter name:           │ github-workflow → execution-plan                                                                                                                                 │
  ├─────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ H1 title                    │ "GitHub Workflow" → "Execution Plan"                                                                                                                             │
  ├─────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ Description                 │ Rewritten around execution of coherent work rather than GitHub mechanics. Adds triggers like "execute the plan", "let's implement", and "reference a planning    │
  │                             │ document"                                                                                                                                                        │
  ├─────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ Cross-refs in peer skills   │ Updated in qa-remediation, qa-review, ux-review, security-review (including security-review's own description which mentioned "github-workflow phase")           │
  ├─────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ Forward-looking project     │ Updated prompts/INSTRUCTIONS.md, prompts/INSTRUCTIONS - TEMPLATE.md, and 4 PRPs                                                                                  │
  │ docs                        │                                                                                                                                                                  │
  └─────────────────────────────┴──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  Historical records deliberately preserved

  11 files under prompts/Phase *, prompts/SKILL - QA Remediation*, prompts/INITIAL Summary.md, and .claude/skills/qa-remediation-workspace/ still reference /github-workflow. Those are completed phase
   plans, past review reports, and frozen eval-run artefacts — rewriting them would falsify what was actually invoked at the time they were written.

  If you want those swept too for consistency, say the word and I'll do a second pass. Otherwise the rename is complete and the live skill registry already picks up execution-plan with the new
  description (visible in the skills list this turn).