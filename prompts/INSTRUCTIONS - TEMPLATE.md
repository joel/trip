


# PREPARATION - Phase Implemenation Preps

Steps:
- Read `PRPs/trip-journal.md`
- Read CLAUDE.md
- Read prompts/INITIAL Summary.md
- Write down the PLAN `prompts/Phase 1.md`
- Stop, do not start coding, wait for my approval before starting any work.

# EXECUTION - Phase Implemenation Action

Start with a fresh context: Clear the context.

Steps:
- Read `PRPs/trip-journal.md`
- Read CLAUDE.md
- Read prompts/INITIAL Summary.md
- Use the project skill /execution-plan to execute the PLAN `prompts/Phase 1.md`
- Write the Steps taken in `prompts/Phase 1 - Steps.md` for trail and audit
- QA at runtime is everything works, use the project skill /product-review, it is critical to use the agent-browser to verify that the integration and design proceed as expected. This is a highly visual re-design task that requires a visual check.



# CODE REVIEW

Go through the PR comments and share your thoughts.
DO NOT FIX IT, give your thoughts first, and wait confirmation.



# DEEP QA Phase

Use the Task tool to spin up parallel sub-agents for review.

Each agent must work independently and write its report to disk before exiting.

Do not wait for one to finish before starting the next.

Task 1 — QA Review
  Instructions: Read .claude/skills/qa-review/SKILL.md and follow it in full for the current branch.
  Write the complete report to prompts/Phase X - QA Review.md.

Task 2 — Security Review
  Instructions: Read .claude/skills/security-review/SKILL.md and follow it in full for the current branch.
  Write the complete report to prompts/Phase X - Security Review.md.

Task 3 — UX Review
  Instructions: Read .claude/skills/ux-review/SKILL.md and follow it in full for the current branch.
  Write the complete report to prompts/Phase X - UX Review.md.

Task 4 - UI Polish
  Instructions: Read .claude/skills/ui-polish/SKILL.md and follow it in full for the current branch.
  Write the complete report to prompts/Phase X - UI Polish Review.md.

Task 5 - UI Designer
  Instructions: Read .claude/skills/ui-designer/SKILL.md and follow it in full for the current branch.
  Ensure UI Component Library is Sync.
  Write the complete report to prompts/Phase X - UI Designer Review.md.

Ensure it respects UI Designer specifications, and keep the local UI Element Library in Sync: `ui_library/README.md`

Once all three tasks complete, read the three reports and give me a consolidated summary of all 🔴 Critical/Broken/Defect findings
