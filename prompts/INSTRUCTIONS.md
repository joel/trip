# New Phase

Follow these steps:
- Draft the next phase PLAN, X, and

Add Social Login.
Use rodauth-omniauth to let people Sign In/up with their Google Account.
Generate a plan with /generate-prp
Write the PLAN down in `prompts/Phase 15 Social Login.md`

/clear # Clear the context to start a new cone

# Execution

To implement the plan, it is critical to use the agent-browser to verify that the integration and design proceed as expected. This is a highly visual re-design task that requires a visual check.

Steps:
- Read `PRPs/trip-journal.md`
- Read CLAUDE.md
- Use the project skill /github-workflow to execute the PLAN `prompts/Phase 11.md`
- Write the Steps taken in `prompts/Phase 11 - Steps.md` for trail and audit
- QA at runtime is everything works, use the project skill /product-review, it is critical to use the agent-browser to verify that the integration and design proceed as expected. This is a highly visual re-design task that requires a visual check.


# Team Agent Review

Use the Task tool to spin up parallel sub-agents for review. Each agent must work independently and write its report to disk before exiting. Do not wait for one to finish before starting the next.

Task 1 — QA Review
  Instructions: Read .claude/skills/qa-review/SKILL.md and follow it in full for the current branch. Write the complete report to prompts/Phase X - QA Review.md.

Task 2 — Security Review
  Instructions: Read .claude/skills/security-review/SKILL.md and follow it in full for the current branch. Write the complete report to prompts/Phase X - Security Review.md.

Task 3 — UX Review
  Instructions: Read .claude/skills/ux-review/SKILL.md and follow it in full for the current branch. Write the complete report to prompts/Phase X - UX Review.md.

Task 4 - UI Polish
  Instructions: Read .claude/skills/ui-polish/SKILL.md and follow it in full for the current branch. Write the complete report to prompts/Phase X - UI Polish Review.md.

Task 5 - UI Designer
  Instructions: Read .claude/skills/ui-designer/SKILL.md and follow it in full for the current branch. Ensure UI Component Library is Sync. Write the complete report to prompts/Phase X - UI Designer Review.md.

Ensure it respects UI Designer specifications, and keep the local UI Element Library in Sync: `ui_library/README.md`

Ensure Bullet N+1 notifications are addressed!

Once all three tasks complete, read the three reports and give me a consolidated summary of all 🔴 Critical/Broken/Defect findings

# After completion

Write the Steps taken in `prompts/Phase X - Steps.md` for trail and audit

Go through the PR comments and share your thoughts. DO NOT FIX IT, give your thoughts first, and wait confirmation.

Fix the issues found, one by one (atomic commit)

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