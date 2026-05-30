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

## Step 8 — Runtime verification
- _pending_

## Step 9 — PR
- _pending_
