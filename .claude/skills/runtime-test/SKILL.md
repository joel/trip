---
name: runtime-test
description: Use after committing code changes to perform mandatory live runtime verification. Triggers when the user says "test live", "runtime test", "verify live", "browser test", or after completing a feature/fix. Rebuilds the app, restarts services, and visually verifies all pages with agent-browser.
---

# Runtime Test Workflow

Perform live runtime verification of the application after code changes. This ensures the app actually works in the Docker environment, not just in unit tests.

## When to Run

Run this workflow:
- After all code changes are committed and tests pass
- Before pushing a branch or creating a PR
- When the user asks to "test live" or "verify in browser"

## Prerequisites

- `agent-browser` CLI installed and available
- Docker services running (app + mail)
- The `bin/cli` command available in the project root

## Workflow

### Step 1: Rebuild and Restart

```bash
bin/cli app rebuild
bin/cli app restart
bin/cli mail start
```

Wait for the health check to pass in the restart output before proceeding.

### Step 2: Verify Home Page (Logged Out)

```bash
agent-browser open https://catalyst.workeverywhere.docker/ && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-home.png
```

Read the screenshot and verify:
- Sidebar navigation renders (Overview link, Dark mode toggle, Sign in, Create account)
- Hero section with "Welcome home" heading
- "Sign in faster" card with Sign in / Create account buttons
- Background gradient decorations visible

### Step 3: Test Account Creation Flow

```bash
agent-browser snapshot -i
```

Find the "Create account" link and click it. Then:

```bash
agent-browser open https://catalyst.workeverywhere.docker/create-account && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-create-account.png
```

Verify the create account page renders with email field and submit button.

Fill the form and submit:

```bash
agent-browser snapshot -i
# Use refs to fill email and click submit
agent-browser fill @eN "runtime-test@example.com"
agent-browser click @eM  # Submit button
agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-after-signup.png
```

Verify flash toast appears confirming account creation.

### Step 4: Verify Email Delivery

```bash
agent-browser open https://mail.workeverywhere.docker/ && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-mail.png
```

Verify a "Verify Account" email was received. Extract the verification link:

```bash
curl -sk https://mail.workeverywhere.docker/messages/1.plain
```

The verify URL uses `localhost:3000` — replace with `https://catalyst.workeverywhere.docker` when navigating.

### Step 5: Verify Account and Test Logged-In State

Navigate to the verify URL (with corrected host):

```bash
VERIFY_KEY=$(curl -sk https://mail.workeverywhere.docker/messages/1.plain | grep -oP 'key=\K[^\s]+')
agent-browser open "https://catalyst.workeverywhere.docker/verify-account?key=$VERIFY_KEY" && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-verified.png
```

Verify:
- User is auto-logged in after verification
- Sidebar now shows: My account, Add passkey, Sign out
- Home page shows "Add a passkey" card instead of "Sign in faster"

### Step 6: Test Users Pages (Requires Admin)

Promote the test user to admin:

```bash
bundle exec rails runner "User.find_by(email: 'runtime-test@example.com')&.update!(roles: [:admin])"
```

Then verify each page:

```bash
# Users index
agent-browser open https://catalyst.workeverywhere.docker/users && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-users-index.png

# New user form
agent-browser open https://catalyst.workeverywhere.docker/users/new && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-users-new.png
```

Verify:
- Users index shows user cards with View/Edit buttons
- "New user" button visible in header
- New user form has Name, Email, and Roles checkboxes

### Step 7: Test Account Page

```bash
agent-browser open https://catalyst.workeverywhere.docker/account && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-account.png
```

Verify: account details card, Edit account and Delete account buttons.

### Step 8: Test Login Page

```bash
agent-browser open https://catalyst.workeverywhere.docker/login && agent-browser wait --load networkidle && agent-browser screenshot /tmp/rt-login.png
```

Verify: email field, Login button, "More Options" footer links.

### Step 9: Test Dark Mode

```bash
agent-browser snapshot -i
# Find and click the "Toggle dark mode" button
agent-browser click @eN  # Dark mode toggle
agent-browser wait 500 && agent-browser screenshot /tmp/rt-dark-mode.png
```

Verify: dark background, light text, theme persists across elements.

### Step 10: Cleanup

```bash
agent-browser close
```

## Handling Failures

If any page shows an error:

1. Read the error message from the screenshot or page text
2. Identify the root cause (missing `.to_s`, nil access, wrong helper, etc.)
3. Fix the code
4. Re-run `bundle exec rake` to ensure tests still pass
5. Commit the fix
6. Restart the app with `bin/cli app restart`
7. Re-verify the failing page

## Checklist

Report results using this checklist:

```
## Runtime Test Results

- [ ] App rebuild succeeds
- [ ] App restart health check passes
- [ ] Mail service running
- [ ] Home page (logged out) renders correctly
- [ ] Create account page renders and form works
- [ ] Verification email received
- [ ] Account verification + auto-login works
- [ ] Home page (logged in) renders correctly
- [ ] Users index page renders correctly
- [ ] New user form renders correctly
- [ ] Account page renders correctly
- [ ] Login page renders correctly
- [ ] Dark mode toggle works
- [ ] No runtime errors on any page
```
