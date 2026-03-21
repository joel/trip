---
name: github-workflow
description: Use this skill for every task that involves code changes in this project. It governs the full lifecycle from GitHub issue creation through Kanban tracking, branching, implementation, testing, live verification, and PR submission. Trigger whenever the user asks to implement a feature, fix a bug, refactor code, or do any work that will result in a commit. Also trigger when the user says "start work", "new feature", "fix issue", "create PR", "push changes", or asks about the project workflow. This skill ensures no step is skipped - especially the GitHub issue, Kanban board updates, and live runtime verification that are easy to forget.
---

# GitHub Workflow

This skill enforces the full development workflow defined in AGENTS.md. Every code change follows this lifecycle: Issue → Kanban → Branch → Implement → Test → Live Verify → Push → PR → Review.

## Why This Matters

Skipping steps (especially GitHub issues, Kanban updates, and live testing) creates tracking gaps and lets runtime bugs slip through. The automated test suite catches logic errors but not rendering issues, broken layouts, or Phlex/ERB integration problems. The live verification step caught a real `Phlex::ArgumentError` in PR #9 that all unit and system tests missed.

## GitHub CLI Authentication

The `GITHUB_TOKEN` environment variable can override keyring-based authentication and cause failures. Always prefix `gh` commands with `unset GITHUB_TOKEN &&`:

```bash
unset GITHUB_TOKEN && gh issue create ...
unset GITHUB_TOKEN && gh pr create ...
unset GITHUB_TOKEN && gh project item-add ...
```

## Project References

- **Repository:** [joel/trip](https://github.com/joel/trip)
- **Issues:** [GitHub Trip Issues](https://github.com/joel/trip/issues)
- **Kanban Board:** [Trip Kanban Board](https://github.com/users/joel/projects/2/views/1) (Project ID: `2`)
- **Available Labels:** `bug`, `enhancement`, `cleanup`, `documentation`, `dependencies`, `ruby`

### Kanban Status IDs

| Status | Option ID |
|--------|-----------|
| Backlog | `f75ad846` |
| Ready | `61e4505c` |
| In progress | `47fc9ee4` |
| In review | `df73e18b` |
| Done | `98236657` |

**Status field ID:** `PVTSSF_lAHNFp3OAUj6X84P9YK-`

## Workflow Steps

### Step 1: Create GitHub Issue

Before writing any code, create an issue with a detailed plan:

```bash
unset GITHUB_TOKEN && gh issue create \
  --repo joel/trip \
  --title "<descriptive title>" \
  --label "<label>" \
  --body "$(cat <<'EOF'
## Summary
<what and why>

## Scope
<bullet list of changes>

## Verification
<how to confirm it works>
EOF
)"
```

Pick the label that best fits: `enhancement` for features, `bug` for fixes, `cleanup` for refactoring, `documentation` for docs.

### Step 2: Add to Kanban Board → Backlog

```bash
unset GITHUB_TOKEN && gh project item-add 2 --owner joel --url <issue-url>
```

The issue starts in **Backlog** by default. Save the item ID from the output (or retrieve it later with `gh project item-list`).

### Step 3: Move to Ready, Then In Progress

To move an issue on the board, you need its **item ID**. Retrieve it:

```bash
unset GITHUB_TOKEN && gh project item-list 2 --owner joel --format json \
  | jq -r '.items[] | select(.content.number == <ISSUE_NUMBER>) | .id'
```

Then update the status:

```bash
# Move to Ready (before starting work)
unset GITHUB_TOKEN && gh project item-edit \
  --project-id PVT_kwHNFp3OAUj6Xw \
  --id <ITEM_ID> \
  --field-id PVTSSF_lAHNFp3OAUj6X84P9YK- \
  --single-select-option-id 61e4505c

# Move to In Progress (when starting work)
unset GITHUB_TOKEN && gh project item-edit \
  --project-id PVT_kwHNFp3OAUj6Xw \
  --id <ITEM_ID> \
  --field-id PVTSSF_lAHNFp3OAUj6X84P9YK- \
  --single-select-option-id 47fc9ee4
```

### Step 4: Create Feature Branch

```bash
git checkout main && git pull origin main
git checkout -b feature/<descriptive-name>
```

Branch naming: `feature/*` for features, `fix/*` for bugs, `docs/*` for documentation, `refactor/*` for refactoring.

### Step 5: Implement Changes

Write code, following project conventions. Use `mise x --` to prefix all Ruby commands.

### Step 6: Pre-Commit Validation

Run these and ensure they all pass before committing:

```bash
mise x -- bundle exec rake project:fix-lint
mise x -- bundle exec rake project:lint
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
```

Or run everything at once:

```bash
mise x -- bundle exec rake
```

### Step 7: Commit

Stage specific files (not `git add .`) and use a descriptive commit message. Overcommit hooks will enforce RuboCop, trailing whitespace, and commit message format (capitalized subject, no trailing period).

If a hook is a false positive, skip only that specific hook and document it:

```bash
SKIP=RailsSchemaUpToDate git commit -m "$(cat <<'EOF'
Your commit message here

Skipped RailsSchemaUpToDate: schema unchanged, migration is no-op

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

Never use `OVERCOMMIT_DISABLE=1`.

### Step 8: Runtime Test Workflow

After committing and before pushing, perform live verification. Use the `/runtime-test` skill for the full checklist, or manually:

```bash
bin/cli app rebuild
bin/cli app restart
bin/cli mail start
```

Then use `agent-browser` to verify all pages render without errors. Fix any issues found, commit the fix, and re-run the test suite.

### Step 9: Push and Create PR

```bash
unset GITHUB_TOKEN && git push -u origin <branch-name>
```

Create the PR with a summary and test plan:

```bash
unset GITHUB_TOKEN && gh pr create \
  --repo joel/trip \
  --title "<PR title>" \
  --body "$(cat <<'EOF'
## Summary
<bullet points of what changed>

## Test plan
- [x] All non-system specs pass
- [x] All system specs pass
- [x] Lint passes
- [x] All overcommit hooks pass
- [x] Visual verification at https://catalyst.workeverywhere.docker

Closes #<issue-number>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Step 10: Move Issue to In Review

```bash
unset GITHUB_TOKEN && gh project item-edit \
  --project-id PVT_kwHNFp3OAUj6Xw \
  --id <ITEM_ID> \
  --field-id PVTSSF_lAHNFp3OAUj6X84P9YK- \
  --single-select-option-id df73e18b
```

## Quick Reference: Complete Flow

```
1. gh issue create          → Create issue with plan
2. gh project item-add      → Add to Kanban (Backlog)
3. gh project item-edit     → Move to Ready, then In Progress
4. git checkout -b feature/ → Create branch
5. <implement changes>      → Write code
6. bundle exec rake         → Lint + tests + system tests
7. git commit               → Overcommit hooks validate
8. /runtime-test            → Live browser verification
9. git push + gh pr create  → Push and open PR (Closes #N)
10. gh project item-edit    → Move to In Review
```
