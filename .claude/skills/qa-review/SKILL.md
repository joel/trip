---
name: qa-review
description: Use this skill after runtime-test completes to perform structured quality assurance on the full feature or fix — checking edge cases, boundary conditions, and regression risk that automated tests may not cover. Trigger when the user says "qa review", "qa check", "edge case review", or after any phase completes before the PR is merged. This skill is adversarial: its job is to break the feature, not validate it. Always prefer testing in the live Docker environment over reading code.
---

# QA Review

Perform structured quality assurance on the changes in the current branch. This is an adversarial pass — attempt to break the feature through edge cases, unexpected input, and user behaviour the implementation agent didn't anticipate.

## Project Context

- **App URL:** `https://catalyst.workeverywhere.docker/`
- **Mail URL:** `https://mail.workeverywhere.docker/`
- **Container:** `catalyst-app-dev`
- **CLI:** Use `bin/cli` for app/service management (`bin/cli app rebuild`, `bin/cli app restart`, `bin/cli mail start`)
- **Ruby commands outside container:** Prefix with `mise x --` (e.g., `mise x -- bundle exec rspec`)
- **Auth framework:** Rodauth (login, create-account, verify-account, email-auth, webauthn)
- **Authorization:** ActionPolicy (`authorize!` in controllers, `allowed_to?` in views)
- **Views:** Phlex components (not ERB)

## Prerequisites

- App running in Docker (`bin/cli app start` or `bin/cli app restart`)
- `agent-browser` and `curl` available
- Mail service running (`bin/cli mail start`)

## Step 1: Understand the Feature

Read the GitHub issue and the diff to understand what was built and what the acceptance criteria are:

```bash
unset GITHUB_TOKEN && gh issue view <ISSUE_NUMBER>
git diff main...HEAD --stat
```

Identify:
- The happy path (what the feature does when everything goes right)
- The inputs (forms, URL params, API calls, events)
- The side effects (emails, DB writes, redirects, Kanban updates)

## Step 2: Verify the Happy Path

Run through the acceptance criteria from the issue, step by step, in the live app. Do not assume the runtime-test covered this — confirm it yourself.

## Step 3: Test Edge Cases

For every input or trigger, test the following:

### Empty / Missing Input
- What happens if a required field is blank?
- What if an optional field is omitted?
- What if a URL param is missing or malformed?

### Boundary Values
- What if a text field is at its maximum length?
- What if a number is 0, negative, or extremely large?
- What if a date is in the past, today, or far future?

### Concurrent / Repeated Actions
- What if the form is submitted twice quickly (double-click)?
- What if the user refreshes mid-flow?
- What if the same email/token is used twice?

### Unauthorized Access
- Can a logged-out user access the new page directly via URL?
- Can a non-admin user access admin-only actions?
- Can user A access user B's resources by guessing a UUID?

### State Transitions
- What if the action is triggered from an unexpected state (e.g. already-verified account, already-approved request)?
- What if the feature is triggered out of order?
- For trips: test actions across all states (planning, started, finished, cancelled, archived)

## Step 4: Verify Side Effects

For every side effect the feature produces, verify it actually happened:

### Emails
```bash
curl -sk https://mail.workeverywhere.docker/messages \
  | python3 -c "import json,sys; [print(m['id'],m['subject'],m['recipients']) for m in json.load(sys.stdin)]"
```

### Database State
```bash
cat > /tmp/qa-check.rb <<'RUBY'
# Example: verify record was created with correct attributes
record = MyModel.last
puts record.inspect
RUBY
docker exec -i catalyst-app-dev bin/rails runner - < /tmp/qa-check.rb
```

**Note:** Use heredoc + `docker exec -i` (not `-it`) for non-interactive runner commands. Ruby bang methods (`save!`, `find_by!`) break in shell because `!` is interpreted by bash — always use the heredoc pattern above.

### Redirects & Flash Messages
Verify the user lands on the correct page after each action and sees appropriate feedback (toast notifications via Stimulus `toast_controller`).

## Step 5: Regression Check

Identify the three most likely existing features to be broken by this change (e.g. if authentication was touched, test login; if the user model was touched, test account editing). Run through those flows manually.

## Output Format

```
## QA Review — <branch name>

### Acceptance Criteria
- [ ] <criterion from issue> — PASS / FAIL / PARTIAL

### Defects (must fix before merge)
- <defect>: <steps to reproduce> — <expected vs actual>

### Edge Case Gaps (should fix or document)
- <gap>: <scenario> — <risk if left unfixed>

### Observations
- <anything notable that isn't a defect>

### Regression Check
- <feature tested> — PASS / FAIL
```

## Fixing Defects

For each Defect, open a fix before the PR is merged. Follow github-workflow commit conventions. Add a regression spec if the defect is logic-based and could silently reappear.

For Edge Case Gaps, ask the user: fix now or create a follow-up issue labelled `bug` or `enhancement`?
