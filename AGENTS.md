# AGENTS.md

This document provides instructions and protocols for AI Agents interacting with this repository. **Follow these guidelines strictly to ensure project consistency.**

## 1. Context & Environment

- **Location Awareness:** Always use `context7` to retrieve the latest version of the project location and environmental state before performing actions.

- **Live Testing:** Use the `agent-browser` tool to verify changes visually or functionally.

- **GitHub CLI:** Always `unset GITHUB_TOKEN` before running `gh` commands. The environment may have a stale token that causes `HTTP 401: Bad credentials` errors. The `gh` CLI falls back to its own auth store when the env var is unset.

    - **Local URL:** `https://catalyst.workeverywhere.docker`

---

## 2. CLI Operations (`bin/cli`)

Pilot the application and infrastructure through the CLI.

### Usage Syntax

`bin/cli COMMAND ACTION [ENV]`

| **Command** | **Description** |
|---|---|
| `app ACTION [ENV]` | Manage the application container. |
| `db ACTION [ENV]` | Manage the database container (migrations, reset, etc.). |
| `mail ACTION` | Manage the local mail service. |
| `services ACTION [ENV]` | Orchestrate all services together. |
| `tree` | Print a tree of all available commands. |
| `help [COMMAND]` | Describe available commands or one specific command. |

### Parameters

- **ACTION:** Common actions include `start`, `stop`, `build`, `logs`, `connect`, `console`, `reset`.

- **ENV:** Options are `dev` | `development` (default) or `prod` | `production`.

---

## 3. Development Workflow & Quality Control

### Pre-Commit Validation

You **must** run these commands and ensure they pass before attempting a commit:

1. **Linting:** `bundle exec rake project:fix-lint` (to autocorrect) then `bundle exec rake project:lint`.

2. **Testing:** `bundle exec rake project:tests` and `bundle exec rake project:system-tests`.

### Git & Overcommit Hooks

The project uses `overcommit`. Commits will fail if the following hooks are not satisfied:

- **Pre-commit:** Checks for trailing whitespace, "FIXME" tokens, and **RuboCop** compliance.

- **Commit-msg:** Enforces **Capitalized Subjects**, no trailing periods, and specific line widths.

- **Action:** If a hook fails, you must resolve the issue in the code or the commit message before re-committing.

---

## 4. Process & Governance

1. **Issue First:** No work without an existing issue in [GitHub Trip Issues](https://github.com/joel/trip/issues). Create one if needed.

2. **Kanban Management:** You are responsible for moving issues across the [Trip Kanban Board](https://github.com/users/joel/projects/2/views/1) (e.g., _To Do_ -> _In Progress_ -> _Done_).

3. **Repository:** All code must be pushed to the [GitHub Trip Repository](https://github.com/joel/trip).

### Workflow Steps

1. Read `AGENTS.md` / `CLAUDE.md` to understand current project rules.
2. Create an issue on [GitHub Trip Issues](https://github.com/joel/trip/issues) with a detailed plan, then move it to **Backlog** on the [Trip Kanban Board](https://github.com/users/joel/projects/2/views/1).
3. Add the appropriate label (e.g., `cleanup`, `feature`, `fix`) to the issue.
4. Before starting work, assign yourself to the issue and move it to **Ready**.
5. Once you start working, move the issue to **In Progress**.
6. Pre-commit validation must include **both** `bundle exec rake project:tests` **and** `bundle exec rake project:system-tests`.
7. When all tests pass and browser verification succeeds, push the branch, create the PR with a description, and move the issue to **In Review**.
8. After the PR receives review comments, you **must** respond to every comment, then resolve each conversation.

### PR Review Response Rules

When a PR receives code review comments:

1. **Read all comments** using `gh api repos/joel/trip/pulls/<PR>/comments`.
2. **Evaluate each comment** — decide whether to act on it, explain why not, or defer to a future phase.
3. **For actionable feedback:** Fix the code, commit, push, then reply explaining what was fixed and in which commit.
4. **For incorrect feedback:** Reply with a clear technical explanation of why no action is needed.
5. **For deferred feedback:** Reply acknowledging the concern and stating which phase or PR will address it.
6. **Reply to every comment** using `gh api repos/joel/trip/pulls/<PR>/comments/<ID>/replies -X POST -f body='...'`. The `<PR>` number is required — omitting it (`gh api repos/joel/trip/pulls/comments/<ID>/replies`) returns `HTTP 404: Not Found`.
7. **Resolve every conversation** after replying using the GraphQL `resolveReviewThread` mutation.
8. Never leave review comments unanswered or unresolved.

### Workflow Rules

- **Never disable overcommit entirely** (`OVERCOMMIT_DISABLE=1`). When a hook indicates a false positive, skip **only** the specific hook: `SKIP=<HookName> git commit ...` (e.g., `SKIP=RailsSchemaUpToDate`). Always add a footnote in the commit message body explaining which hook was skipped and why, for audit trail purposes.

- **Do not use `[skip ci]` markers in commit messages.** CI decides whether to run via `paths-ignore` in `.github/workflows/ci.yml` (non-runtime paths such as `**/*.md`, `prompts/**`, `ui_library/**`, `PRPs/**`, `docs/**`, `designs/**`, `notes/**` are ignored automatically). Using `[skip ci]` caused CI to be skipped on `main` after rebase-and-merge when the PR's last commit carried the marker, even though the merged diff contained runtime changes. If a new directory should be exempt from CI, add it to `paths-ignore` instead of relying on commit-message markers.

- **Test full user journeys, not just page rendering.** Runtime tests must verify multi-step flows end-to-end (e.g., request access → admin approves → invitation email sent → user signs up → user verified). A page rendering correctly does not guarantee the business logic behind it works. If a feature involves events, subscribers, or background jobs, verify the downstream effects actually happen (check emails in MailCatcher, check database records).

- **Rails.event structured events (Rails 8.1).** Subscribers must respond to `#emit(event)`, not `#call`. The event is a hash: `event[:name]`, `event[:payload]`, `event[:tags]`, etc. Register with `Rails.event.subscribe(subscriber)` and use an optional filter block: `{ |e| e[:name].start_with?("prefix.") }`.

- **Shell escaping with `docker exec` + `bin/rails runner`.** Ruby bang methods (`save!`, `find_by!`) break in shell because `!` is interpreted by bash. Use heredoc redirect instead: `docker exec -i container bin/rails runner - < /tmp/script.rb`.

- **Rodauth forms lose query parameters on POST.** If a URL contains query params (e.g., `?invitation_token=xxx`), the Rodauth form POST will not include them. Add hidden fields in the Phlex view to carry params through.

- **Pre-fill forms from context, not just params.** When a URL carries context (tokens, IDs) that determines valid input, pre-fill and lock the relevant form fields. If the backend validates that an email matches an invitation, the form must pre-fill that email from the invitation record and make it read-only. Never rely on the user to type something that the system already knows — mismatches cause silent rejections that look like bugs.

---

## MCP Authentication and Agent Identity

MCP requests carry two pieces of identity:

1. **`MCP_API_KEY`** — shared Bearer token for the endpoint (channel auth). A valid key grants **unrestricted read/write access to all domain data** through the 23 registered MCP tools (journal entries, images, comments, reactions, checklists, plus read access to trips). Trip creation and member administration are deliberately not exposed — those remain human-only. Missing/wrong key → HTTP 401.
2. **`X-Agent-Identifier` header** — slug of a registered `Agent` record (e.g. `jack`, `maree`). Resolves to the agent's system User, which is used as the author/actor for all writes (journal entries, comments, reactions). Missing or unknown slug → JSON-RPC error `-32001` with a readable message (HTTP 200 so the client sees it in-band). Register agents via Rails console: `Agent.create!(slug: "...", name: "...", user: <system_user>)`.

Each agent has its own `@system.local` User. Subscription filters (`JournalEntries::Create#subscribe_trip_members`) exclude system actors from auto-subscription, so agents don't email themselves.

---

## 5. Runtime Test Workflow (Mandatory)

After all code changes are committed and tests pass, you **must** perform a live runtime verification before pushing the branch or creating a PR.

### Steps

1. **Rebuild the app:**
   ```
   bin/cli app rebuild
   ```

2. **Restart the app:**
   ```
   bin/cli app restart
   ```

3. **Start the mail service:**
   ```
   bin/cli mail start
   ```

4. **Verify email delivery** at `https://mail.workeverywhere.docker/` using `agent-browser`.

5. **Visually verify the app** at `https://catalyst.workeverywhere.docker/` using `agent-browser`:
   - Home page renders correctly (logged out and logged in states).
   - Authentication flows work (create account, verify email, sign in, sign out).
   - All CRUD pages render and function (e.g., Users index, show, new, edit).
   - Account management pages render (show, edit).
   - Dark mode toggle works.
   - Flash messages (toasts) appear and dismiss.
   - Sidebar navigation links and active states are correct.

6. **Fix any runtime errors** found during live testing, commit the fix, and re-run the full test suite before pushing.

### Runtime Verification Scripts

When verifying server-side logic via `bin/rails runner` (e.g. MCP tools, service objects), build fixtures with **FactoryBot factories** rather than raw `Model.create!`:

```ruby
entry = FactoryBot.create(:journal_entry, trip: trip)
```

Raw `create!` silently misses required associations (e.g. `JournalEntry#author`, `Comment#user`), causing avoidable `RecordInvalid` failures and wasted rebuild/run cycles. Factories already encode every required association and a valid default state.

### Checklist

This checklist must be satisfied before pushing:

- [ ] `bin/cli app rebuild` succeeds
- [ ] `bin/cli app restart` health check passes
- [ ] `bin/cli mail start` is running
- [ ] Home page renders (logged out)
- [ ] Create account + email verification flow works
- [ ] Home page renders (logged in, with auth nav)
- [ ] Users CRUD pages render correctly
- [ ] Account page renders correctly
- [ ] Login page renders correctly
- [ ] Dark mode toggle works
- [ ] No runtime errors in any page

## Skill Self-Evaluation

After using any skill from this project, append a brief retrospective:

**Skill used**: [skill name]
**Step audit**:
- Any step that was redundant or unnecessary → note it
- Any step whose output was unused → note it
- Any command that produced an error or required a workaround → note it
- Any step where you deviated from the skill's instructions → explain why

**Improvement suggestion**: One concrete, actionable edit to the SKILL.md that would fix the most significant issue found. If none, write "No changes suggested."
