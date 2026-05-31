# Phase 25 — Improve Persistence: Steps (flight recorder)

Append-only audit trail. Plan: `prompts/Phase 25 Improve Persistance.md`.

## Step 1 — Issue
- **Issue:** [#192](https://github.com/joel/trip/issues/192) — "Phase 25 —
  Improve Persistence: soft-delete + JournalEntry versioning".
- **Plan:** `prompts/Phase 25 Improve Persistance.md` (v2, decisions A–E
  resolved; attachments deferred to Phase 26).
- User approved the plan and instructed to implement via `/execution-plan`.

## Step 4 — Branch
- `feature/phase-25-improve-persistence` off `main`.

## Step 7 — Commits
- `6706594` — plan + steps docs `[skip ci]`.
- `9111208` — T1 add discard 2.0 + paper_trail 17.0 (both resolve on Rails 8.1 /
  Ruby 4.0.1).
- `0205e50` — T2 `discarded_at` column + index on trips/journal_entries/comments.
- `5bf1f57` — T3 paper_trail `versions` table, UUID-corrected (`id: :uuid`,
  `item_id` uuid). **Deviation:** kept paper_trail default text/YAML for
  `object`/`object_changes` (plan said `:json`) — most battle-tested for
  `reify`, avoids serializer-vs-column mismatch.
- `aedb414` — T4 `include Discard::Model` + `default_scope { kept }` + cascade
  discard (trip→entries→comments); parent-only restore. Smoke-tested.
- `5afc3c8` — T5 Delete actions `destroy!` → `discard!`.
- `0ebd3b3` (after lint fixups) — T6 Restore actions + `*.restored` events
  documented in actions event inventory.
- `0ebd3b3` — T7 paper_trail on JournalEntry `name` + `ActionText::RichText`
  body via `on_load(:action_text_rich_text)`; Create/Update wrapped in
  `PaperTrail.request(whodunnit: Current.actor&.id)`. **Simplification:**
  `only: [:name]` already excludes `discarded_at`, so the plan's separate
  `ignore: [:discarded_at]` was dropped as redundant. Smoke-tested: title + body
  both version, whodunnit correct, reify restores prior title.
- `b229dad` — T8 `AuditLog::Builder` subject finders → `with_discarded` so
  delete-event summaries survive soft-delete; added `"restored"` verb phrase.
- T9 read-path sweep: **no code change needed.** Verified `default_scope { kept }`
  reaches associations, direct model queries, `find`, counts, and crucially the
  `left_joins(:comments)` ON clause in `list_journal_entries` (Rails 8.1 emits
  `ON comments.discarded_at IS NULL AND ...`), so MCP listings/exports/counts all
  exclude discarded rows automatically.

## Step 7 — Commits (continued)
- T10 (`10cfdbf`) — restore endpoints + `restore?` policies (mirror `destroy?`)
  + minimal trash UI (trips index `?discarded=1` with Restore buttons).
  `with_discarded.discarded` used to list deleted rows (bare `.discarded`
  self-contradicts the kept default scope).
- T11 serializer fix — switched paper_trail to the **JSON serializer**: Psych 4
  `safe_load` rejected `ActiveSupport::TimeWithZone` on `reify`
  (`Psych::DisallowedClass`). JSON store in the text columns makes reverts
  reliable. (Committed with `SKIP=RailsSchemaUpToDate` — only a comment in an
  already-applied migration changed; schema intentionally unchanged.)
- T11 tests — model/action/MCP/builder/paper_trail specs + `:discarded` factory
  traits.

## Step 8 — Validation + runtime verification
- `rake project:lint` clean (527 files, no offenses); Packwerk no violations.
- `rake project:tests`: 839 examples, 0 failures, 2 pending (pre-existing).
- `rake project:system-tests`: **93 examples, 0 failures**.
  - First run showed 69/93 failures — root cause was a **stale Tailwind build**
    artifact (dev/JIT build from console smoke-tests stripped production
    classes), making text non-visible to Capybara. `rails tailwindcss:build`
    produced **no diff** to the committed CSS and the suite went green. Not a
    code defect; the committed `app/assets/builds/tailwind.css` was always
    correct.
- Live browser walk (`agent-browser`, logged in as joel@acme.org via
  MailCatcher magic link):
  - Trips index renders with the new "Recently deleted" link + "New Trip".
  - Deleted "Patagonia Trek" → "Trip deleted." flash, vanished from index
    (5 → 4 trips).
  - `?discarded=1` "Recently Deleted" view listed it with a Restore button.
  - Restore → "Trip restored." flash, reappeared on the index (back to 5).
  - DB checks: discard/undiscard preserved the trip's 3 memberships; editing an
    entry title created a paper_trail version with correct whodunnit and
    `reify` restored the prior title; discarding an entry cascade-discarded its
    comment while both rows survived in `with_discarded`.
  - Dark-mode toggle works.

## Step 9 — PR
- PR [#193](https://github.com/joel/trip/pull/193); issue moved to In Review.

## Step 9a — Review feedback (restore buttons in the Activity feed)
- User reported no restore button in the Activity feed. The deferred
  per-entry/comment restore UI is better placed there (it lists every deletion
  with context), so added it instead of a separate trash view.
- `7cf2dee` — `AuditLogsController` batch-loads the discarded auditable per
  `*.deleted` row (no N+1), authorises with `restore?`, and only offers restore
  when the parent chain is kept; `AuditLogCard` renders a Restore button_to from
  denormalised columns (defaults keep the live-stream job render unaffected).
  Request specs added (shows for restorable own; hidden once restored; hidden to
  a contributor on another's entry). Verified live: feed Restore button →
  "Entry restored." → entry back in the kept scope.
- `e8ddc58` — fix: gate the feed Restore button on the row's own `.deleted`
  action (it keyed on auditable_id, so every event for a discarded entry showed
  Restore). Regression spec asserts exactly one button across deleted+updated+
  restored.

## Step 9b — Review feedback (revert edits from the feed)
- User expected to restore content edits too. Chose "revert from feed rows".
- `991eed7` — each `*.updated` row carries its diff `{ field => [old, new] }`;
  a Revert button re-applies the old values via the record's Update action (a
  forward audit + version event). Controller batch-loads kept auditables for
  update rows, authorises with `update?`, keys the revert map by audit_log id
  (per-row). PATCH `:revert` route + turbo-confirm button. Covers column fields
  (title/description/location/dates) and comment body; journal-entry rich-text
  body is not a column so it never appears in the feed diff (agreed out of
  scope). Request specs (shows/reverts/no-button/404). Verified live: feed
  Revert on a "Name: Foo → Bar" row restored the name to "Foo".

## Step 9c — Review feedback (PR #193 Codex bot)
- One P2: trips `?discarded=1` trash view was gated only in the view, not the
  controller — a non-restorer could list discarded trip names/dates. Fixed
  `52df38d`: `@discarded = params[:discarded].present? && allowed_to?(:restore?,
  Trip)`; specs cover both paths. Replied + thread resolved.

## Step 9d — Documentation
- `0b9bbfe` — added "Persistence safety (Phase 25)" section to `AGENTS.md`
  (parallel to Audit Journal) and `docs/persistence-safety.md` (Mermaid
  lifecycle + delete/restore sequence + revert flow + file map); linked both from
  `README.md`. Authored via the documentation-manager agent, then hardened the
  Mermaid (newlines → single-line/`<br/>`, removed a pipe from a flowchart label
  that would confuse the parser).
- `2a1efcd` — corrected a stale "Text + YAML" comment in the object_changes
  migration (serializer is JSON).

## Step 12/13 — Merge, deploy, release (audit trail)

| Item | Value |
|------|-------|
| PR #193 | rebase-merged to `main` (tip `160abb0`) |
| CI/Deploy on #193 merge | **skipped** — intermediate `[skip ci]` commits skipped the whole `main` push (the documented footgun); nothing deployed |
| Re-trigger | PR #195 (`docs/phase-25-restore-actions`, issue #194) — added `*::Restore` docstrings + a docs note, touching `.rb` so CI is not path-ignored |
| #195 merge | `main` tip `cdfb371`; **CI + Deploy both green** → Phase 25 deployed |
| Release | **`phase-25`** — <https://github.com/joel/trip/releases/tag/phase-25> (`--generate-notes`, covers PR #193 + #195) |
| Issues → Done | #192 (Phase 25), #194 (re-trigger) |
| Follow-ups opened | #196 (Phase 26 — re-attachable attachments), #197 (dev: RecordAuditLogJob not processed locally) |

**Lesson:** never use `[skip ci]` — it skips CI *and* deploy on `main` after a
rebase-merge. For a `main` change that genuinely should not deploy (docs/no-op),
use `[skip deploy]` instead (gated by `deploy.yml`'s
`if: !contains(head_commit.message, '[skip deploy]')`).
