# AGENTS.md

This document provides instructions and protocols for AI Agents interacting with this repository. **Follow these guidelines strictly to ensure project consistency.**

## 1. Context & Environment

- **Location Awareness:** Always use `context7` to retrieve the latest version of the project location and environmental state before performing actions.

- **Live Testing:** Use the `agent-browser` tool to verify changes visually or functionally.

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

### Workflow Rules

- **Never disable overcommit entirely** (`OVERCOMMIT_DISABLE=1`). When a hook indicates a false positive, skip **only** the specific hook: `SKIP=<HookName> git commit ...` (e.g., `SKIP=RailsSchemaUpToDate`). Always add a footnote in the commit message body explaining which hook was skipped and why, for audit trail purposes.
