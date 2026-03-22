# New Phase

Follow these steps:
- Write the plan in `prompts/Phase X.md`

/clear # Clear the context to start a new cone

# Execution

Steps:
- Read `PRPs/trip-journal.md`
- Read CLAUDE.md
- Use the project skill /github-workflow to execute the PLAN `prompts/Phase X.md`
- Write the Steps taken in `prompts/Phase X - Steps.md` for trail and audit
- QA at runtime is everything works, use the project skill /runtime-test
- Run the project skill /qa-review, write the report in `prompts/Phase X - QA Review.md` for trail and audit
- Run the project skill /security-review, write the report in `prompts/Phase X - Security Review.md` for trail and audit
- Run the project skill /ux-review, write the report in `prompts/Phase X - UX Review.md` for trail and audit

# After completion

Write the Steps taken in `prompts/Phase X - Steps.md` for trail and audit

Go through the PR comments and share your thoughts.

Fix one by one (commit) the comments
Reply to the comments so we leave a clear trace
Mark Comversation as resolved.

Use the project skill /runtime-test and check that everything is working as expected.

# When finished

The PR has been merged:
- Check the base branch
- Pull the latest changes
- Draft the next phase PLAN.
- Wait for my approval before starting any work.