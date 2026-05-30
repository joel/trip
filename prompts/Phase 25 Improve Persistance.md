# Phase 25 — Improve Persistence (Soft-Delete + Versioning)

> **Status:** PLAN v2 — awaiting approval. Do **not** start coding until the
> user approves. Decisions A–E are now **resolved** (see §3); the only open
> item is the attachment re-attach scope (§9, recommended **deferred**).

PRP-style implementation plan: context, locked decisions, task-by-task changes,
and executable validation gates.

---

## 1. Goal

Make the three **critical, user-authored** models harder to lose or corrupt:

1. **Soft deletion** (`jhawthorn/discard`) on **Trip**, **JournalEntry**,
   **Comment** — a "delete" sets `discarded_at` instead of removing the row, so
   accidental deletes are recoverable.
2. **Versioning** (`paper-trail-gem/paper_trail`) of **JournalEntry title and
   content** — every change to the entry's `name` and its rich-text `body` is
   captured as an immutable `versions` row with the field-level diff and the
   acting user, so accidental edits can be inspected and reverted.

> **Gem change from v1 of this plan:** `audited` was rejected (stale: last
> commit ~6 months ago, ~180 open issues, ~40 open PRs). **`paper_trail` 17.0.0**
> is the replacement — actively maintained (released 2025-10-24), `activerecord
> >= 7.1` with **no upper bound** (Rails 8.1 ✓), no Ruby ceiling (Ruby 4.0.1 ✓),
> and first-class `reify` for reverting/undeleting versions.

**How this relates to Phase 21's `AuditLog` (no overlap):**

| System | Granularity | Question it answers |
|---|---|---|
| `AuditLog` (Phase 21) | Event-sourced domain feed | "Who did what, when, across the trip?" |
| `paper_trail` (this phase) | Column-level diffs, per record, **reversible** | "What did this entry's title/content say before, and revert it." |
| `discard` (this phase) | Row lifecycle | "It's gone — get it back." |

### Why both `discard` *and* `paper_trail` (not redundant)

They look overlapping — both can "bring something back" — but `paper_trail`
cannot replace `discard` **in this design**:

1. **Only `JournalEntry` is versioned.** Trip and Comment have no `paper_trail`,
   so a hard delete of either would be unrecoverable. Imitating soft-delete via
   reify would force full-object `paper_trail` onto Trip + Comment too.
2. **Hard `destroy` cascades wipe the graph; `reify` won't rebuild it.**
   `Trip dependent: :destroy` also destroys memberships, entries, checklists,
   exports, reactions. `version.reify.save` restores only the one row; restoring
   the graph needs the fragile `paper_trail-association_tracking` extension and
   risks FK ordering violations. `discard` destroys nothing, so `undiscard`
   brings the intact graph back instantly.
3. **Content + images survive only with `discard`.** A hard destroy purges
   Active Storage blobs and deletes the separate `ActionText::RichText` body;
   reifying the `journal_entries` row restores neither. `discard` never touches
   them.
4. **`default_scope { kept }` needs a surviving row** to support a listable,
   recoverable "trash" — paper_trail-only leaves nothing to list.

**Division of labour:** `discard` = recoverable *deletion* of whole records +
graph + attachments, hidden by default. `paper_trail` = *edit history* of
title/content with revert. Neither covers the other.

> **Interaction:** because delete now means *discard* (an update to
> `discarded_at`), a real `destroy` never fires for these models, so
> paper_trail's `on: :destroy` would be dead code. JournalEntry therefore uses
> `on: %i[create update]` (see Task 7 / §4.4).

---

## 2. Scope

**In scope**
- `discard` on Trip, JournalEntry, Comment (column, scopes, action changes,
  cascade).
- `paper_trail` versioning of JournalEntry **`name`** (title) and its
  **Action Text `body`** (content) — see §4.4 for the rich-text mechanism.
- Restore-from-discard capability: model + `Restore` actions + **minimal**
  restore endpoint/button (Decision E), authorization mirroring `destroy?`
  (Decision D).
- Make every read path (web views, MCP `list_*`, feed, exports, policies,
  counts) exclude discarded records via `default_scope { kept }` (Decision A).
- Tests + mandatory live runtime verification.

**Out of scope / deferred (tracked as follow-up issues)**
- **Re-attachable attachments** (soft-delete of Active Storage images) —
  recommended as **follow-up Phase 26**; design sketch in §9.
- A revision/diff **viewer + revert UI** for `paper_trail` versions (data is
  captured now; revert is console/endpoint-level this phase, full UI later).
- A full "Trash / Recycle bin" listing UI (minimal restore only — Decision E).
- `paper_trail` on Trip, Comment, Reaction, Checklists (JournalEntry only).
- Retention/pruning of the `versions` table.

---

## 3. Resolved decisions

- **A — Scoping:** ✅ `default_scope -> { kept }` on all three models
  (safety-by-default; never leak discarded rows). `with_discarded` / `unscoped`
  only on restore/admin paths.
- **B — Cascade:** ✅ cascade discard **down** (Trip→entries→comments); on
  restore, **restore the targeted record only** (do not auto-restore children).
- **C — Content versioning:** ✅ version **title (`name`) and content (rich-text
  `body`)**. Title via `has_paper_trail` on `JournalEntry`; body via
  `has_paper_trail` on `ActionText::RichText` (§4.4).
- **D — Restore authorization:** ✅ **mirror the existing `destroy?` rules**
  (owner-can-restore-own, superadmin always), not superadmin-only.
- **E — Restore UI depth:** ✅ **minimal** — restore endpoint + a "Restore"
  button on a thin discarded-items affordance + console capability. No full
  Trash listing this phase.

---

## 4. Gem compatibility & gotchas (researched)

### 4.1 `discard` `~> 2.0`
Pure Ruby, no AR ceiling → Rails 8.1 / Ruby 4.0.1 fine. API: `include
Discard::Model`; scopes `kept` / `discarded` / `with_discarded`; methods
`discard(!)` / `undiscard(!)` / `discarded?`; callbacks `before/after_discard`,
`before/after_undiscard`. **Validations are not run on discard/undiscard.**

### 4.2 `paper_trail` `~> 17.0` (17.0.0, 2025-10-24)
- Dependency: `activerecord >= 7.1` (no upper bound), `request_store ~> 1.4`.
  Rails 8.1 ✓, Ruby 4.0.1 ✓. Still **smoke-test** `bundle install` + suite at
  install time.
- `has_paper_trail on: [:create, :update, :destroy], only:/ignore:/skip:`.
- Versions carry `whodunnit` (a string — store the actor's UUID).

### 4.3 UUID primary keys (critical)
App uses **UUID PKs** (`id: :uuid`, `sqlite_crypto` fork; Phase 21 `audit_logs`
uses `t.uuid :auditable_id`). The `paper_trail:install` migration defaults
`item_id` to `bigint`. We **must** edit the generated migration:
- `create_table :versions, id: :uuid`
- `item_id` → `:uuid` (mirrors the `audit_logs` precedent).
- `--with-changes` adds the `object_changes` diff column (use `:json`; SQLite
  has no `jsonb`).

```bash
mise x -- bin/rails generate paper_trail:install --with-changes
# then edit migration: create_table :versions, id: :uuid ; t.uuid :item_id
```

### 4.4 Versioning the rich-text **content** (the crux of Decision C)
`JournalEntry#body` is `has_rich_text :body` — a separate `ActionText::RichText`
row, **not** a column on `journal_entries`. `paper_trail` on `JournalEntry`
alone would version the **title** (`name`) but **never the body**.

**Mechanism:** also enable paper_trail on the rich-text model:
```ruby
# config/initializers/paper_trail_action_text.rb
Rails.application.config.to_prepare do
  ActionText::RichText.include(PaperTrail::Model) unless
    ActionText::RichText.respond_to?(:paper_trail)
  ActionText::RichText.has_paper_trail(on: %i[create update])
end
```
Only the JournalEntry body uses rich text in this app (trip/comment bodies are
plain `text`), so this is narrowly scoped in practice. Each body edit creates a
`versions` row (`item_type: "ActionText::RichText"`); revert = reify that
version. Reverting the **title** reifies the `JournalEntry` version.

> JournalEntry declaration: track `name`, but **don't let a discard create a
> title version**. Since `discard` only touches `discarded_at`,
> `ignore: [:discarded_at]` keeps the title history clean. And because delete is
> now a discard (no real `destroy` fires — see §1 "Why both"), `on:` omits
> `:destroy`:
> ```ruby
> has_paper_trail only: [:name], ignore: [:discarded_at], on: %i[create update]
> ```
> (Recommended minimal mapping for "title + content". If broader column
> protection is wanted later, drop `only:` and keep `ignore: [:discarded_at]`.)

### 4.5 `paper_trail` whodunnit — wrap writes in `PaperTrail.request(whodunnit:)`
Reuse the existing `Current.actor` plumbing (`app/models/current.rb`, set by
`ApplicationController#set_audit_context` for web and `McpController` for MCP).
Wrap the JournalEntry persistence in the action:
```ruby
PaperTrail.request(whodunnit: Current.actor&.id) do
  entry.save!   # or update!/discard!
end
```
Works uniformly across web, MCP, console, and jobs without relying on
paper_trail's controller hook.

---

## 5. Implementation blueprint (tasks in order)

> Branch `feature/phase-25-improve-persistence`; GitHub issue first
> (`/execution-plan`); atomic commits — one concern each.

### Task 1 — Add gems
```ruby
gem "discard", "~> 2.0"
gem "paper_trail", "~> 17.0"
```
`mise x -- bundle install`. Commit `chore(deps): add discard and paper_trail`.

### Task 2 — Migration: `discarded_at` on the three tables
```ruby
class AddDiscardedAtToCriticalModels < ActiveRecord::Migration[8.1]
  def change
    add_column :trips,           :discarded_at, :datetime
    add_column :journal_entries, :discarded_at, :datetime
    add_column :comments,        :discarded_at, :datetime
    add_index  :trips,           :discarded_at
    add_index  :journal_entries, :discarded_at
    add_index  :comments,        :discarded_at
  end
end
```
Migrate; confirm `db/schema.rb` (watch `RailsSchemaUpToDate` hook).

### Task 3 — Migration: `versions` table (UUID-corrected)
Generate (§4.3), then edit: `create_table :versions, id: :uuid`,
`t.uuid :item_id`, `object`/`object_changes` as `:json`. Migrate; confirm schema.

### Task 4 — `include Discard::Model` + cascade callbacks
- `trip.rb`: `include Discard::Model`; `default_scope -> { kept }`;
  `after_discard { journal_entries.kept.find_each(&:discard) }`.
- `journal_entry.rb`: `include Discard::Model`; `default_scope -> { kept }`;
  `after_discard { comments.kept.find_each(&:discard) }`.
- `comment.rb`: `include Discard::Model`; `default_scope -> { kept }`.

(Per-record `find_each(&:discard)` so nested callbacks reach grandchildren;
`discard_all` would skip them. No `after_undiscard` cascade — Decision B.)

### Task 5 — `Delete` actions: `destroy!` → `discard!`
`app/actions/{trips,journal_entries,comments}/delete.rb`: change the private
destroy step's `record.destroy!` to `record.discard!`. **Keep** the
ID-capture-before pattern and the existing `*.deleted` event emission unchanged.

### Task 6 — New `Restore` actions + `*.restored` events
Add `app/actions/{trips,journal_entries,comments}/restore.rb`, mirroring `Delete`:
```ruby
module JournalEntries
  class Restore < BaseAction
    def call(journal_entry:)
      yield restore(journal_entry)
      yield emit_event(journal_entry)
      Success(journal_entry)
    end

    private

    def restore(entry) = entry.undiscard! ? Success() : Failure(entry.errors)
    def emit_event(entry)
      Rails.event.notify("journal_entry.restored",
                         journal_entry_id: entry.id, trip_id: entry.trip_id)
      Success()
    end
  end
end
```
Restore controllers must load via `with_discarded` (default scope hides it).

### Task 7 — `paper_trail` on JournalEntry title + rich-text body
- `journal_entry.rb`:
  ```ruby
  has_paper_trail only: [:name], ignore: [:discarded_at], on: %i[create update]
  ```
  (`on:` omits `:destroy` — delete is now a discard, so no real destroy fires.)
- Add `config/initializers/paper_trail_action_text.rb` enabling paper_trail on
  `ActionText::RichText` (§4.4) so **content** edits are versioned.
- In `JournalEntries::Create` / `Update` / `Delete`, wrap the persistence
  (`create!` / `update!` / `discard!`) in `PaperTrail.request(whodunnit:
  Current.actor&.id) { ... }` (§4.5). Note: the body write happens inside the
  same request, so the rich-text version inherits the same whodunnit.

### Task 8 — Fix `AuditLog::Builder` finders (Phase 21 interaction — Decision A)
`default_scope { kept }` hides discarded rows from the builder's
`Model.find_by(id:)`, breaking delete-event summaries. Switch to `with_discarded`:
- `trip_subject` → `Trip.with_discarded.find_by(...)`
- `journal_entry_subject` → `JournalEntry.with_discarded.find_by(...)`
- `comment_subject` → `Comment.with_discarded.find_by(...)` + the
  `JournalEntry.with_discarded.find_by` it uses for trip resolution
- `reaction_subject`'s JournalEntry/Comment lookups → `with_discarded`
- Add `"restored" => "restored"` to `VERB_PHRASES`. The subscriber's prefix
  filter (`"trip.", "journal_entry.", "comment."`) already matches
  `*.restored` — verify, no change expected.

### Task 9 — Read-path safety sweep
`default_scope` auto-filters most paths; **verify** each:
- MCP `list_journal_entries`, `list_comments`, `get_trip` exclude discarded;
  `delete_*` tools now soft-delete (no API contract change).
- Exports (Markdown/ePub) omit discarded entries/comments.
- Counts/badges (comment counts, notifications) auto-scoped.
- Grep for any pre-existing `unscoped`/`with_deleted` — none expected.

### Task 10 — Policies + minimal restore route/UI (Decisions D & E)
- `TripPolicy` / `JournalEntryPolicy` / `CommentPolicy`: add `restore?`
  **mirroring `destroy?`** (Decision D), e.g. JournalEntry:
  `(superadmin? || (contributor? && own_entry?)) && record.trip.writable?`.
- Routes: `member { patch :restore }` for trips, journal_entries, comments.
- Controllers: `restore` action → `authorize!` →
  `JournalEntries::Restore.new.call(...)` → redirect with flash. Load the record
  with `with_discarded`.
- **Minimal** surface: a "Restore" button reachable by an authorized user on a
  thin discarded view (e.g. a `?discarded=1` filter on the relevant index,
  authorized via policy) — not a full Trash UI (Decision E).

### Task 11 — Tests (RSpec, `spec/`)
- **Model specs:** `discard` stamps `discarded_at`; `kept`/`discarded` scopes;
  `default_scope` hides discarded from `.all` + associations; cascade
  (discard trip ⇒ entries + comments discarded); `undiscard` restores parent
  only (child stays discarded — Decision B).
- **Action specs:** `Delete` now `change(Model, :count).by(0)` but
  `Model.discarded.count` +1; `*.deleted` still emitted. New `restore_spec`:
  undiscards + emits `*.restored`.
- **paper_trail specs:** updating `name` creates a `JournalEntry` version with
  the diff and `whodunnit == Current.actor.id`; editing the **body** creates an
  `ActionText::RichText` version; `version.reify` restores prior title/content;
  discard does **not** create a title version (`ignore: [:discarded_at]`).
- **MCP specs:** `delete_*` soft-delete; `list_*` exclude discarded.
- **Builder spec:** a *discarded* entry/comment still yields a non-nil subject
  with correct `trip_id` (regression for Task 8).
- **Factories:** add `:discarded` trait (`after(:create, &:discard!)`) to
  trips/journal_entries/comments.

### Task 12 — Validation gates (must pass before PR)
```bash
mise x -- bundle exec rake project:fix-lint
mise x -- bundle exec rake project:lint
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
```
Live runtime verification (`/product-review`):
```bash
bin/cli app rebuild && bin/cli app restart && bin/cli mail start
```
`agent-browser` walk:
- Delete a journal entry → disappears from the trip; DB row survives with
  `discarded_at`; no orphan leakage in feed/exports/MCP.
- Delete a comment (Turbo Stream removal) → soft-deleted.
- Delete a trip → vanishes from index; memberships/entries intact underneath.
- Restore (authorized user) → record reappears.
- Edit an entry **title** and **body** → `versions` rows with diffs + correct
  whodunnit; reify in console restores prior values.

---

## 6. Risks / watch-list
- paper_trail Rails 8.1 runtime smoke-test (constraint allows it; verify early).
- `default_scope` interactions — counts, `AuditLog::Builder` (Task 8), Telegram
  idempotency partial-unique index (a discarded entry still holds its
  `(trip_id, telegram_message_id)` slot; acceptable for V1, noted).
- UUID `versions.item_id` hand-edit (§4.3) — generator defaults to bigint.
- Rich-text body versioning (§4.4) is the make-or-break for Decision C — without
  the `ActionText::RichText` paper_trail, **content is not versioned**. Covered
  by a dedicated spec.
- Reify of a rich-text version must be tested explicitly (Action Text serializes
  to `body` HTML; confirm `reify.save` round-trips).

---

## 7. Confidence

**8.5 / 10** for one-pass implementation. Mechanical work (gems, migrations,
action edits, tests) is well-understood and the codebase fits cleanly
(centralised `Delete`/`Create`/`Update` actions + `Current.actor`). The −1.5 is
the `default_scope` blast radius across read paths (Task 9) and the Action Text
rich-text versioning + reify round-trip (§4.4) — both have dedicated specs and
runtime checks.

---

## 8. References
- `discard`: <https://github.com/jhawthorn/discard> (`~> 2.0`).
- `paper_trail`: <https://github.com/paper-trail-gem/paper_trail> (17.0.0;
  `activerecord >= 7.1`, no upper bound).
- UUID install note: edit the generated migration to
  `create_table :versions, id: :uuid` + `t.uuid :item_id`.
- Existing patterns: `app/actions/CLAUDE.md`, `app/models/audit_log/builder.rb`
  (Phase 21), `app/models/current.rb` (actor plumbing),
  `db/migrate/20260515100000_create_audit_logs.rb` (UUID column precedent).

---

## 9. Follow-up Phase 26 (proposed) — Re-attachable attachments

**Requested consideration:** "deleting an attachment should be able to re-attach
it." **Recommendation: defer to its own phase** — it is materially more complex
than discard/paper_trail and orthogonal to them.

**Why it's not a quick add:** Active Storage has **no native soft-delete**.
Removing an image deletes the `ActiveStorage::Attachment` join row (and, on
`purge`, the blob + stored file). Today the app only *attaches* images
(`app/actions/journal_entries/{attach,upload}_*`); there is no first-class
"remove image" action yet, so this is partly **new feature surface**, not just
hardening. A real solution needs to:
1. Intercept removal so the **blob and file are retained** (detach without
   `purge`, or a `discarded_at` on a custom attachment-tracking row).
2. Record the detached attachment (paper_trail on a join model, or a dedicated
   `DetachedAttachment` record holding `blob_id` + entry + actor + timestamp).
3. Provide a **re-attach** action + UI that re-creates the attachment from the
   retained blob, plus a real-purge path for permanent deletion.
4. Reconcile with `OrphanBlobsCleanupJob` (which purges unattached blobs ~1h
   later) so retained blobs aren't swept.

**Proposed split:** ship Phase 25 (discard + paper_trail) now; open a tracking
issue "Phase 26 — Re-attachable attachments" with the sketch above. Confirm at
approval whether you want it folded in or deferred.
