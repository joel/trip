# New Phase

Follow these steps:
- Write the plan in `prompts/Phase X.md`

/clear # Clear the context to start a new cone

# Execution

Steps:
- Read `PRPs/trip-journal.md`
- Read CLAUDE.md
- Use the project skill /github-workflow to execute the PLAN `prompts/Phase 7.md`
- Write the Steps taken in `prompts/Phase 7 - Steps.md` for trail and audit
- QA at runtime is everything works, use the project skill /product-review

Use the Task tool to spin up parallel sub-agents for review. Each agent must work independently and write its report to disk before exiting. Do not wait for one to finish before starting the next.

Task 1 — QA Review
  Instructions: Read .claude/skills/qa-review/SKILL.md and follow it in full for the current branch. Write the complete report to prompts/Phase X - QA Review.md.

Task 2 — Security Review
  Instructions: Read .claude/skills/security-review/SKILL.md and follow it in full for the current branch. Write the complete report to prompts/Phase X - Security Review.md.

Task 3 — UX Review
  Instructions: Read .claude/skills/ux-review/SKILL.md and follow it in full for the current branch. Write the complete report to prompts/Phase X - UX Review.md.

Task 4 - UI Polish
  Instructions: Read .claude/skills/ui-polish/SKILL.md and follow it in full for the current branch. Write the complete report to prompts/Phase X - UI Polish Review.md.

Once all three tasks complete, read the three reports and give me a consolidated summary of all 🔴 Critical/Broken/Defect findings

# After completion

Write the Steps taken in `prompts/Phase X - Steps.md` for trail and audit

Go through the PR comments and share your thoughts.

Fix one by one (commit) the comments
Reply to the comments so we leave a clear trace
Mark Comversation as resolved.

Use the project skill /product-review and check that everything is working as expected.

# When finished

The PR has been merged:
- Check the base branch
- Pull the latest changes
- Draft the next phase PLAN.
- Wait for my approval before starting any work.