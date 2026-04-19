Optimisation loop — final results

  4 iterations completed before iteration 5 crashed on a transient claude -p error. All 4 had identical scores:

  ┌──────────────┬────────────────────────────────────────────────────────┬──────────────┬─────────────┐
  │  Iteration   │                      Description                       │ Train recall │ Test recall │
  ├──────────────┼────────────────────────────────────────────────────────┼──────────────┼─────────────┤
  │ 1 (original) │ my hand-written                                        │ 0%           │ 0%          │
  ├──────────────┼────────────────────────────────────────────────────────┼──────────────┼─────────────┤
  │ 2            │ optimiser rewrite #1 (more "pushy")                    │ 0%           │ 0%          │
  ├──────────────┼────────────────────────────────────────────────────────┼──────────────┼─────────────┤
  │ 3            │ optimiser rewrite #2 (triggers-first structure)        │ 0%           │ 0%          │
  ├──────────────┼────────────────────────────────────────────────────────┼──────────────┼─────────────┤
  │ 4            │ optimiser rewrite #3 (signals-and-artifacts structure) │ 0%           │ 0%          │
  └──────────────┴────────────────────────────────────────────────────────┴──────────────┴─────────────┘

  All iterations: 100% precision, 0% recall, 54% train / 57% test accuracy.

  Precision of 100% just means the skill never false-triggered on the 11 should-NOT cases. Recall of 0% means it never triggered on any of the 9 should-trigger cases either. The skill was never
  invoked.

  What this means

  The description isn't the bottleneck. The skill-creator guide calls this out explicitly:

  ▎ Claude only consults skills for tasks it can't easily handle on its own … simple, one-step queries like "read this PDF" may not trigger a skill even if the description matches perfectly.

  Our "remediate 6 findings" queries are substantive, but Claude can (and does) carry out the steps directly — gh issue create, atomic commits, gh issue close — because those tools are already in its
   toolkit. The skill offers procedural guidance, not new capability. Even in this conversation, when you asked for the QA round 2 work earlier, I carried out the remediation directly from the live
  context without ever consulting the skill file. The eval measures exactly that behaviour — and confirms it's systematic.

  What I'd do (two paths)

  1. Accept it. Keep the skill for explicit invocation.
  The skill is still valuable when:
  - You explicitly say /qa-remediation (Skill tool finds it by name).
  - A future session without this conversation's context has to figure out the workflow from scratch.
  - The find-skills skill surfaces it when you ask "how do I systematically turn findings into tracked commits?"

  This is the cheap option. The current description is already as good as it's going to get by natural-language triggering alone.

  2. Change what the skill offers.
  Make it do something Claude can't do solo. Candidates:
  - A bundled script (scripts/remediate.py) that reads a findings report, creates all issues in one pass, and prints a ready-made commit scaffold per finding. Triggering then depends on Claude seeing
   "oh, there's a script that does exactly this."
  - A specific format enforcer — e.g. Claude reads review findings from a fixed file shape and translates them mechanically. If the review reports had a known schema, the skill becomes a code path,
  not prose.

  Both need more thought than a description tweak.

  My recommendation: path 1. The skill captures the discipline in SKILL.md; descriptions optimise triggering but can't force a skill to be used when the main tools already cover the work. Leave the
  current description, keep it discoverable by name, move on.

  Want me to write this up as a self-eval section in the skill itself, plus keep the workspace artefacts for the record? Or just end here?