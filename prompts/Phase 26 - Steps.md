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

## Steps 7–12 — policies, controllers, UI, feed, tests, docs

| commit | what |
|--------|------|
| test(actions) | action specs for the 4 media actions + :discarded video factory trait |
| feat(policy) | JournalEntryVideoPolicy destroy?/restore? (entry author/superadmin, trip writable) + spec |
| feat(controllers) | JournalEntryVideosController + JournalEntryImagesController (destroy/restore) + nested routes + JournalEntry has_many :detached_attachments + request specs (happy + non-member 403) |
| feat(ui) | Activity-feed Restore for *.removed media (build_restorable handles discard-based video + existence-based DetachedAttachment; AuditLogCard restore_path) + request specs |
| feat(ui) | per-item Remove buttons on image/video tiles (MediaRemoval module) |
| fix(actions) | **critical**: RemoveImage uses attachment.delete not destroy — has_many_attached dependent: :purge_later would purge the blob (file loss) when the job runs inline (production). Inline-adapter regression spec added. |
| fix(ui) | remove overlay always-visible (a11y) + overflow-hidden wraps only the image (was clipping the overlay); video destroy → redirect-with-flash |
| test(system) | :js media remove→feed→restore journey (2 ex); Bullet safelist for AS attachment :record false-positive |
| docs | AGENTS.md + persistence-safety.md + actions event inventory |

**The system spec earned its keep:** it caught the `attachment.destroy` →
`purge_later` → blob-purge bug that the action spec (under the :test queue
adapter, which never runs the purge job) could not. Fix = `attachment.delete`;
regression locked in with an inline-adapter spec.

**Validation:** `project:lint` clean; `project:tests` **888 ex, 0 failures**
(2 pre-existing pending) on a reset test DB.

## Validation — two bugs caught by the test layers

1. **Blob purge on image removal (critical, caught by the :js system spec).**
   `has_many_attached` defaults to `dependent: :purge_later`, so
   `attachment.destroy` purges the blob (deletes the file) once the job runs.
   The action spec missed it (the `:test` adapter never runs the purge job); the
   system spec's `:inline` adapter exposed it. Fix: `attachment.delete`. Locked
   in with an inline-adapter regression spec.
2. **N+1 on the trip show page (caught by a server-side render check).** The card
   renders each entry's videos, but `TripsController#show` did not eager-load
   `:videos` → Bullet raised in test → the page 500'd → no entries rendered →
   `journal_entries_spec`/`audit_logs_spec` failed. Fix: eager-load
   `videos: [web/poster blobs]` on show (mirrors the gallery query + plan §11).

**System specs (each green individually):** journal_entries 6/0,
journal_entry_videos 3/3, journal_entry_media_removal 2/0, audit_logs 5/0,
trip_gallery 4/4. The full rake suite thrashes Chrome locally (env limit, not a
code failure — same as Phase 25's local run); CI is the authoritative gate.
