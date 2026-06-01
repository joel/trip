# Phase 26 — Re-attachable Media · Steps (flight recorder)

Append-only. Why and in what order, readable top-to-bottom.

Plan: `prompts/Phase 26 Re-attachable Media.md`.

---

## Step 1 — Issue

- **Issue:** [#196](https://github.com/joel/trip/issues/196) — "Phase 26 —
  Re-attachable attachments (soft-delete for Active Storage)". Deferred from
  Phase 25 (`prompts/Phase 25 Improve Persistance.md` §9); pre-existing.
- **Plan:** `prompts/Phase 26 Re-attachable Media.md` — **APPROVED 2026-06-01**.
  D1 images+videos; D2 Activity-feed restore; D3 soft-delete + restore only
  (no user purge this phase). Cascade: entry-discard cascades to videos,
  **parent-only restore** (mirror Phase 25).
- Label: `enhancement`. Kanban: added to board → Ready → In Progress.

## Step 4 — Branch

- `feature/phase-26-reattachable-media` off `main`.

## Steps 2–6 — Implementation (branch feature/phase-26-reattachable-media)

| sha | what |
|-----|------|
| (docs) | plan + steps `[skip ci]` |
| feat(db) | DetachedAttachment model+migration; JournalEntryVideo include Discard::Model + default_scope { kept } + discarded_at; JournalEntry after_discard cascades to videos (parent-only restore) |
| 186d328 | JournalEntryVideos::Delete + ::Restore (discard/undiscard + journal_entry_video.removed/.restored) |
| 1c0ee98 | JournalEntries::RemoveImage + ::RestoreImage (detach-without-purge → DetachedAttachment; re-attach + destroy; detached_attachment.removed/.restored) |
| fix(jobs) | OrphanBlobsCleanupJob excludes DetachedAttachment blobs (**load-bearing** §5.3) + 2 specs |
| feat(events) | AuditLogSubscriber captures journal_entry_video.*/detached_attachment.*; Builder journal_entry_video_subject + detached_attachment_subject; builder specs (removed+restored × both) |

Decisions: two retention mechanisms — videos discard the row (blobs stay
attached, never orphaned); images detach-without-purge into DetachedAttachment
(its existence == removed state; doubles as feed auditable). Image events use
entity `detached_attachment` (distinct from `journal_entry`) so the auditable is
the per-item record, not the entry — the feed Restore can key on it. Reused the
existing `removed`/`restored` verb phrases (no new ones). Verified each step in
the test env (local-disk storage): blob retained on image remove, discard
cascade, builder summaries read naturally.
