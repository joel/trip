# Phase 20 — Steps (audit trail)

> Append-only log of decisions, commits, and verifications.
> Plan: [`prompts/Phase 20 Complete MCP Server.md`](Phase%2020%20Complete%20MCP%20Server.md).

---

## 1. Issue + plan

- **Issue:** [#138 — Phase 20 — Complete MCP Server (content curation tools)](https://github.com/joel/trip/issues/138) (label: `enhancement`).
- **Plan:** `prompts/Phase 20 Complete MCP Server.md`.
- **User approved the plan** after a question-and-answer round resolved §17 (HTML body, both author fields, hard pre-flight subscriber audit, 11 atomic commits, archived trips included, position allowed).

## 1a. Kanban

- **Blocked on scope:** `gh auth` keyring token is missing `read:project` / `write:project`. Same situation as Phase 19. Card transitions (Backlog → Ready → In Progress → In Review → Done) must be done manually, or after `gh auth refresh -s read:project,project`.

## 2. Branch

- `feature/phase20-complete-mcp-server` (off `main`).

## 3. Pre-flight subscriber audit (§17 Q3 — hard gate)

Verified that the 6 new events Phase 20 newly emits via the MCP surface do not trigger emails to `@system.local` users:

| Event | Subscriber action | Verdict |
|-------|--------------------|---------|
| `journal_entry.deleted` | None — `JournalEntrySubscriber#emit` only handles `journal_entry.created` and `journal_entry.images_added` | Safe (event currently unconsumed) |
| `comment.updated` | `CommentSubscriber` logs only | Safe |
| `comment.deleted` | `CommentSubscriber` logs only | Safe |
| `checklist.created` | `ChecklistSubscriber` logs only | Safe |
| `checklist.updated` | `ChecklistSubscriber` logs only | Safe |
| `checklist.deleted` | `ChecklistSubscriber` logs only | Safe |
| `checklist_item.created` | `ChecklistSubscriber` logs only | Safe |

`NotificationSubscriber` filter (`event_subscribers.rb:21-23`) restricts to `journal_entry.created` and `comment.created` — neither is a new event in Phase 20. No filters needed; proceeding to tool implementation.

## 4. Commits

### Branch-setup commit

- `ee4cc81` — Add Phase 20 plan + this Steps audit trail (`[skip ci]`).

### Blocker: pre-existing env break (resolved out-of-band)

While running commit 1's specs, `bundle exec` could not boot Rails:
`LoadError: cannot load such file -- zip/zip`. Root cause: dependabot
merged `rubyzip 3.3` (#129) to `main`, but `gepub 0.6.4.6` still uses
the removed `require 'zip/zip'`. Two further dependabot bumps
(rubocop 1.86.2 / rubocop-rails 2.35 / rubocop-capybara) activated CI
cops the local `--lint`-only task never caught.

Per the user's call, fixed on a dedicated branch first:

- **Issue #139**, **PR #140** (`fix/gepub-rubyzip-3-compat`), merged to
  `main` (commits `855c55a`, `85ca5fa`).
  - `c97e880` — bump `gepub ~> 2.0` (uses `require 'zip'`, pins rubyzip
    `>=3.0,<3.3`); rename stale `Capybara/NegationMatcherAfterVisit`
    todo entry.
  - `711c9d4` — autocorrect `have_content`→`have_text` (88) +
    `Layout/MultilineMethodCallIndentation` (1); defer
    `Rails/StrongParametersExpect` (30) to `.rubocop_todo.yml` with a
    rationale (require→expect changes failure semantics; warrants its
    own reviewed refactor).
- **Follow-up owed:** dedicated issue for the `Rails/StrongParametersExpect`
  migration across 14 controllers (deferred, not dropped).
- Phase 20 branch rebased on the new `main`; commit-1 WIP restored from
  stash; local validation now fully functional.

### Tool commits

| # | SHA | Tool | Notes |
|---|-----|------|-------|
| 1 | `a50c1ae` | `get_journal_entry` | HTML body via `body.to_s`; spec split to satisfy `RSpec/MultipleExpectations` |
| 2 | `91fcdda` | `list_trips` | All states incl. archived; counts batched via grouped queries (Bullet-clean); uses raw `start_date`/`end_date` not effective (avoids per-row N+1) |
| 3 | `4e46f18` | `list_comments` | Both `author_email` + `author_name`; `includes(:user)` |
| 4 | `eaa019b` | `list_reactions` | Unpaginated (bounded); refactored server-spec registry assertion to `match_array` against a `let` (old `include` list tripped `RSpec/ExampleLength` as tools grew) |
