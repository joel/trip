# PRP: Phase 26 — Re-attachable Media (per-item soft-delete + restore for images & videos)

**Status:** ✅ **APPROVED (2026-06-01).** D1–D3 resolved; cascade = entry-discard cascades to videos, **parent-only restore** (mirror Phase 25). Execute via `/execution-plan` on `feature/phase-26-reattachable-media`.
**Date:** 2026-06-01
**Type:** Feature + hardening — first-class **remove media** action (new surface) made **soft and reversible from day one**, surfaced as Restore in the Activity feed.
**Tracking issue:** [#196](https://github.com/joel/trip/issues/196) — "Phase 26 — Re-attachable attachments (soft-delete for Active Storage)". Deferred from Phase 25 (`prompts/Phase 25 Improve Persistance.md` §9).
**Builds on:** Phase 25 (discard + paper_trail + Activity-feed Restore/Revert), Phase 23b (`JournalEntryVideo` model), Phase 21 (AuditLog feed).
**Confidence:** **7/10** one-pass. Videos are a near-verbatim Phase-25 clone (`Discard::Model` on an existing model). Images are the real risk: Active Storage has **no native soft-delete**, so removal must detach-without-purge into a retention record and reconcile with `OrphanBlobsCleanupJob` — net-new infra with no in-repo precedent.

---

## 1. Decisions (resolved with product owner 2026-06-01)

| # | Question | **Resolution** | Consequence |
|---|----------|----------------|-------------|
| D1 | Media scope | ✅ **Images + videos** (uniform). | Two retention mechanisms (see §5): videos = discard the model row; images = a `DetachedAttachment` retention record. |
| D2 | Where do remove + restore live? | ✅ **Activity feed** — a remove button on each media item; removal becomes a `*.removed` audit row with a **Restore** button, mirroring Phase 25's entry/comment Restore. Reuses `AuditLogsController#build_restorable` + `AuditLogCard`. | No separate trash UI. One recoverability surface, consistent with Phase 25. |
| D3 | User-facing permanent delete (purge)? | ✅ **Soft-delete + restore only.** Removed media is retained + restorable indefinitely this phase; a real-purge path is deferred (later phase / admin / cleanup job). | Smaller, lower-risk. Matches Phase 25, which shipped restore without a user purge. **`OrphanBlobsCleanupJob` must be taught not to sweep retained image blobs** (see §5.3). |

---

## 2. Problem Statement

Phase 25 made `Trip`/`JournalEntry`/`Comment` recoverable via soft-delete. **Media was deferred (§9).** Today there is **no first-class "remove media" action at all** — verified: no remove/detach/purge route, controller path, or UI for a single image or video. Entry-level discard hides media implicitly (discard the entry → its media hides with it; restore → it comes back), but a user cannot remove **one** photo or clip from an entry, and if such an action were added naively it would be **destructive**: removing an `ActiveStorage::Attachment` and purging drops the blob + stored file in SeaweedFS irreversibly.

Phase 26 ships the missing capability **already safe**: per-item remove for images and videos, retained and restorable from the Activity feed, never a hard purge.

---

## 3. Goals & Non-Goals

### Goals
1. **Remove one image / one video** from a journal entry (web UI + the action layer), authorised like `destroy?` on the parent entry.
2. **Removal is soft & reversible.** Videos: `JournalEntryVideo` soft-deletes (Phase-25 discard). Images: detach without purge into a `DetachedAttachment` retention record; the blob + file survive.
3. **Restore from the Activity feed.** Each `*.removed` row gets a **Restore** button (mirrors Phase 25), re-attaching the image / undiscarding the video.
4. **No accidental purge.** `OrphanBlobsCleanupJob` is taught to skip blobs held by a non-purged `DetachedAttachment`. Discarded `JournalEntryVideo` rows keep their attachments, so their blobs are never orphaned.
5. **Consistency with entry discard.** Discarding an entry cascades discard to its videos (parent-only restore), mirroring the existing comment cascade; images already ride along with the surviving entry row.

### Non-Goals (deferred / out of scope)
- **User-facing permanent delete / purge** (D3) — later phase. No "delete forever" button this phase.
- Reordering media, cover-selection, bulk media operations.
- Versioning of media (paper_trail on blobs) — removal/restore is discard-style, not diff-style.
- MCP `remove_*` tools — agents only *add* media today; per-item removal stays human-only this phase (open a follow-up if wanted).
- Soft-delete of the `web`/`poster` renditions independently of their `source` — a video is one unit.

---

## 4. Codebase Context (exact precedents to clone)

| Concern | Precedent | What to mirror |
|---|---|---|
| Discard a model + default kept scope + cascade | `JournalEntry`/`Comment` (`include Discard::Model`, `default_scope -> { kept }`, `after_discard`), `db/migrate/*_add_discarded_at_to_critical_models.rb` | Apply **verbatim** to `JournalEntryVideo`: `discarded_at` column+index, `Discard::Model`, kept default scope; add videos to `JournalEntry after_discard`. |
| Delete action (discard) | `app/actions/journal_entries/delete.rb`, `comments/delete.rb` | `JournalEntryVideos::Delete` → `video.discard!` + emit `journal_entry_video.removed`. New `JournalEntries::RemoveImage`. |
| Restore action | `app/actions/{trips,journal_entries,comments}/restore.rb` | `JournalEntryVideos::Restore` → `undiscard!` + emit `journal_entry_video.restored`. New `JournalEntries::RestoreImage`. |
| Feed Restore button | `app/controllers/audit_logs_controller.rb` (`build_restorable`, `discarded_records`, `restorable?`), `app/components/audit_log_card.rb` (`render_restore`, `restore_path`) | Extend `AUDITABLE_MODELS`, `restore_path`, and `restorable?` parent-chain check to `JournalEntryVideo` and `DetachedAttachment`. |
| Event → audit row | `app/models/audit_log/builder.rb` (`VERB_PHRASES`, `*_subject`, `build_subject` → `:"#{@entity}_subject"`) | Add verb phrases + a `journal_entry_video_subject` and `detached_attachment_subject` resolving `trip_id` via the entry **`with_discarded`** (subject after discard/destroy). |
| Explicit-UUID blob creation | `app/lib/active_storage_blob_builder.rb` (`upload`), `:with_images` factory | Re-attach path uses the retained blob directly (already persisted); specs build blobs via the builder. |
| Policies | `app/policies/{trip,journal_entry,comment}_policy.rb` (`restore?` mirrors `destroy?`) | New `JournalEntryVideoPolicy` (`destroy?`/`restore?` = own entry + `trip.writable?`). Image remove/restore authorised through `JournalEntryPolicy`. |
| Orphan reconciliation | `app/jobs/orphan_blobs_cleanup_job.rb` (24h cutoff, `left_joins(:attachments).where(id: nil)`) | Add `.where.not(id: DetachedAttachment.kept.select(:blob_id))` (or equivalent) so retained image blobs are never swept. |
| Actor plumbing | `app/controllers/application_controller.rb#set_audit_context` (`Current.actor`), `Builder#resolve_actor` | Unchanged — events auto-attribute via `Current.actor`. |
| Factories/specs | `spec/factories/*` (`:discarded`, `:with_images`), `spec/actions/*/restore_spec.rb` | `:discarded` trait on the video factory; `:with_video`/`:with_images` for the image path; restore-action + request + feed specs. |

---

## 5. Architecture & Key Decisions

### 5.1 Videos — clean Phase-25 discard (low risk)

`JournalEntryVideo` becomes soft-deletable exactly like `JournalEntry`:

```ruby
class JournalEntryVideo < ApplicationRecord
  include Discard::Model
  default_scope -> { kept }            # discarded videos never leak into reads
  # ... existing belongs_to / has_one_attached / enum / scope :ready / broadcast
end
```

- **Migration:** `add_column :journal_entry_videos, :discarded_at, :datetime` + index.
- **Why blobs are safe:** discard sets `discarded_at` but the **row still exists**, so its `source`/`web`/`poster` `ActiveStorage::Attachment` rows still point at it → the blobs are never "unattached" → `OrphanBlobsCleanupJob` ignores them. **No orphan-job change needed for video.**
- **`scope :ready`** now composes with the kept default scope (already correct: `where(status: :ready)` on a kept base). All gallery/card/lightbox reads (`entry.videos`, `videos.ready`) auto-exclude discarded videos.
- **Restore is parent-only**, like comments: `JournalEntry after_discard { videos.kept.find_each(&:discard) }` (new — currently cascades to comments only), **no `after_undiscard`**.
- **`dependent: :destroy`** on `has_many :videos` is retained but, like the other models, only fires on a true hard destroy — which the app no longer triggers.
- **Broadcast:** discard is an `update` that doesn't touch `status`, so `broadcast_status_change` (gated on `saved_change_to_status?`) won't fire. Add a small `after_discard`/`after_undiscard` Turbo broadcast to remove/restore the tile on open viewers (mirrors #177), or accept a manual refresh — **minor, decide in implementation.**

### 5.2 Images — `DetachedAttachment` retention record (the real work)

Active Storage has **no soft-delete**. `has_many_attached :images` are opaque `ActiveStorage::Attachment` join rows with no per-image model. To remove-and-restore one image we **detach the join row without purging the blob**, and record the detachment in a new model that doubles as the **feed auditable identity**:

```ruby
# db/migrate/XXXX_create_detached_attachments.rb  (id: :uuid)
create_table :detached_attachments, id: :uuid do |t|
  t.references :journal_entry, type: :uuid, null: false, foreign_key: true, index: true
  t.uuid    :blob_id,      null: false          # the retained ActiveStorage::Blob
  t.uuid    :actor_id                            # who removed it (nullable)
  t.string  :filename                            # denormalised for feed render
  t.string  :content_type
  t.bigint  :byte_size
  t.timestamps
end
add_index :detached_attachments, :blob_id
```

- **Existence = removed state.** A `DetachedAttachment` row exists **only while the image is removed**. Re-attach destroys it. No discard flag on it — its presence is the flag. (Simpler than a `discarded_at`; the feed offers Restore iff the row still exists, exactly like Phase 25's button vanishing once restored.)
- **Remove (`JournalEntries::RemoveImage`):** locate the `ActiveStorage::Attachment` for the target blob on the entry → create `DetachedAttachment(journal_entry_id, blob_id, actor_id, filename, content_type, byte_size)` → **`attachment.destroy` (NOT `purge`)** so the blob + file survive → emit `journal_entry.image_removed` (payload: `detached_attachment_id`, `blob_id`, `journal_entry_id`, `trip_id`). The audit **auditable is the `DetachedAttachment`** so the feed Restore button can key on it.
- **Restore (`JournalEntries::RestoreImage`):** load `DetachedAttachment` (and its blob) → `entry.images.attach(blob)` → `detached.destroy!` → emit `journal_entry.image_restored`.
- **Identifying "the target image" in the UI:** the remove button carries the **blob `signed_id`** (or attachment id) of the image tile; the action resolves it against `entry.images.attachments`. (Phase 23b precedent: forms already speak `signed_id`.)

### 5.3 OrphanBlobsCleanupJob reconciliation (load-bearing — must not lose data)

Today the job purges any blob with **zero** attachments older than 24h. A detached-but-retained image blob has **zero** attachments → it would be swept in 24h = silent data loss. Fix the purge scope to exclude blobs held by a `DetachedAttachment`:

```ruby
scope = ActiveStorage::Blob
        .left_joins(:attachments)
        .where(active_storage_attachments: { id: nil })
        .where(active_storage_blobs: { created_at: ...cutoff_time })
        .where.not(id: DetachedAttachment.select(:blob_id))   # ← retained blobs are safe
```

A spec must prove a detached blob **survives** a cleanup run and a genuinely-orphaned blob is still purged. This is the single highest-risk line in the phase.

### 5.4 Feed integration (mirror Phase 25 exactly)

- **`AuditLog::Builder`** — add to `VERB_PHRASES`: `"image_removed" => "removed an image from"`, `"image_restored" => "restored an image to"`, `"removed" => "removed"` (exists), and for videos either reuse `"removed"`/`"restored"` via a `journal_entry_video` entity or add explicit phrases. Add `journal_entry_video_subject` and `detached_attachment_subject`, both resolving `trip_id` from the entry **`with_discarded`** and setting `record:` to the auditable (the video / the `DetachedAttachment`) so `build_restorable` keys correctly.
- **`AuditLogsController#build_restorable`** — extend `AUDITABLE_MODELS` with `JournalEntryVideo` and `DetachedAttachment`; `restorable?` parent-chain check: video → `video.journal_entry.present?`; detached → `detached.journal_entry.present?` (both with the entry kept). For videos load via `with_discarded`; a `DetachedAttachment` is a live row (offer Restore whenever it still exists).
- **`AuditLogCard#restore_path`** — add cases: `JournalEntryVideo` → `restore_trip_journal_entry_video_path(trip_id, entry_id, video)`; `DetachedAttachment` → `restore_image_trip_journal_entry_path(trip_id, entry, detached)` (or a dedicated route — see §6).
- **Visibility** unchanged: media events are trip-scoped; `AuditLogPolicy` already hides the feed from viewers/guests (404).

### Why these choices
- **Two mechanisms, not one forced abstraction:** a video is already a model — discarding it is free, correct, and orphan-safe. Forcing images through the same model would mean a fake per-image model; forcing videos through `DetachedAttachment` would throw away the clean discard. Use each where it fits (KISS).
- **`DetachedAttachment` as both retention + auditable:** one row answers "what's retained", "who removed it", "what to show in the feed", and "what Restore acts on". No parallel bookkeeping.
- **No purge this phase (D3):** every removal is recoverable; the irreversible path is deferred until the recoverable one is proven in production.

---

## 6. Routes

```ruby
resources :trips do
  resources :journal_entries do
    # NEW — per-item media removal + restore
    resources :images, only: %i[destroy], controller: "journal_entry_images" do
      member { patch :restore }     # or carry blob signed_id; see note
    end
    resources :videos, only: %i[destroy], controller: "journal_entry_videos" do
      member { patch :restore }
    end
  end
end
```

- **Images** have no per-image id; the `destroy`/`restore` target is the **blob `signed_id`** (remove) and the **`DetachedAttachment` id** (restore). Concretely: `DELETE /trips/:t/journal_entries/:e/images/:signed_id` and `PATCH .../images/:detached_id/restore`. Finalise the param shape in implementation; keep it RESTful and the feed `restore_path` consistent.
- **Videos** use the real `JournalEntryVideo` id: `DELETE .../videos/:id`, `PATCH .../videos/:id/restore`.

---

## 7. Task List (ordered) — `/execution-plan`, Track "Phase 26"

GitHub issue **#196** (exists) → Kanban Ready→In Progress → branch `feature/phase-26-reattachable-media` → **atomic commits** → `prompts/Phase 26 - Steps.md` flight recorder each step → `/product-review` → PR → reviews → release `phase-26`.

1. `docs:` open `prompts/Phase 26 - Steps.md`; move #196 Ready→In Progress.
2. `feat(db): DetachedAttachment model + migration` (uuid, blob_id/actor_id + denormalised filename/type/size) **and** `discarded_at` on `journal_entry_videos`; `JournalEntryVideo include Discard::Model` + `default_scope { kept }`; `JournalEntry after_discard` cascades to videos. Run migrate; **`RailsSchemaUpToDate` green**.
3. `feat(actions): JournalEntryVideos::Delete + ::Restore` (discard/undiscard + `journal_entry_video.removed`/`.restored` events) + specs.
4. `feat(actions): JournalEntries::RemoveImage + ::RestoreImage` (detach-without-purge into `DetachedAttachment`; re-attach + destroy record; `journal_entry.image_removed`/`.image_restored`) + specs.
5. `fix(jobs): OrphanBlobsCleanupJob excludes retained DetachedAttachment blobs` + spec (detached blob survives; true orphan still purged). **Load-bearing.**
6. `feat(events): AuditLog::Builder verb phrases + journal_entry_video_subject + detached_attachment_subject` (`with_discarded`) + builder specs (removed **and** restored cases).
7. `feat(policy): JournalEntryVideoPolicy (destroy?/restore?)`; image remove/restore via `JournalEntryPolicy` + policy specs.
8. `feat(controllers+routes): journal_entry_images / journal_entry_videos destroy+restore` controllers + nested routes + request specs.
9. `feat(ui): remove button on each image/video tile` in `JournalEntryCard` (+ lightbox/gallery affordance) — confirm-on-remove; Tailwind JIT → `bin/cli app rebuild`.
10. `feat(ui): feed Restore for media` — extend `AuditLogsController#build_restorable` (`AUDITABLE_MODELS`, `restorable?`) + `AuditLogCard#restore_path` for `JournalEntryVideo` + `DetachedAttachment` + request specs (shows for restorable; hidden once restored; hidden to non-owner).
11. `test:` `:js` system spec — remove an image and a video → tile gone → feed shows a `*.removed` row with Restore → click → media reappears; `:discarded` video factory trait.
12. `docs:` update `docs/persistence-safety.md` (media row in the lifecycle + the `DetachedAttachment` / orphan-reconciliation diagram), `AGENTS.md` "Persistence safety" section, `app/actions/README.md` event inventory.
13. Runtime: `bin/cli app rebuild && app restart && mail start` → §9 checklist live via `agent-browser`.
14. `/security-review` (detach-not-purge correctness, orphan-sweep exclusion, authz on remove/restore, signed_id handling) → `/qa-review` → PR → review → release `phase-26`.

---

## 8. Testing Strategy

| Level | What | Where |
|---|---|---|
| Model | `JournalEntryVideo`: discarded videos excluded from default scope, `with_discarded` sees them, `ready` composes with kept; entry `after_discard` cascades to videos (parent-only restore). | `spec/models/journal_entry_video_spec.rb` |
| Action | `JournalEntryVideos::{Delete,Restore}`: discard/undiscard toggles kept membership, emits the right event. `JournalEntries::{RemoveImage,RestoreImage}`: blob **retained** (not purged) on remove, `DetachedAttachment` created/destroyed, image re-attached on restore, events emitted. | `spec/actions/...` |
| Job | `OrphanBlobsCleanupJob`: a blob held by a `DetachedAttachment` **survives** a run; a genuinely-unattached blob past cutoff is still purged. | `spec/jobs/orphan_blobs_cleanup_job_spec.rb` (extend) |
| Builder | `image_removed`/`image_restored`/`journal_entry_video.removed`/`.restored` → correct `trip_id` (via `with_discarded`), verb phrase, and auditable (DetachedAttachment / video). Cover the **removed** case, not only restored. | `spec/models/audit_log/builder_spec.rb` |
| Request | feed Restore shows for a restorable own item; hidden once restored; hidden to a contributor on another's entry; remove/restore controllers authorise via policy (403/404 for non-owners). | `spec/requests/...` |
| System (`:js`) | Real journey: entry with an image + a ready video → remove each → tiles vanish, gallery/lightbox skip them → Activity feed shows the `*.removed` rows with Restore → restore both → media reappears in card + gallery. | `spec/system/media_soft_delete_spec.rb` |
| Factory | `:discarded` trait on the video factory; reuse `:with_images`/`:with_video`. | `spec/factories/journal_entry_videos.rb` |

**Real-journey rule:** the `:js` spec must actually remove → assert the blob/row is retained → restore → assert the media renders again, and assert the `*.removed` audit row exists. CI driver split (Phase 22 lesson): playback/visibility assertions are `:js` (selenium); rack_test parity for the rest.

## 9. Runtime Test Checklist (live via `agent-browser`)

- [ ] Remove one image from an entry → tile disappears; entry/gallery/lightbox still render
- [ ] The blob + file are **retained** (rails runner: blob still exists, `DetachedAttachment` row present) — **not** purged
- [ ] Remove one video → poster tile disappears; other media unaffected; `JournalEntryVideo` `discarded_at` set, blobs intact
- [ ] Activity feed shows a "removed an image/video" row with a **Restore** button
- [ ] Restore image → re-attaches, reappears in card + gallery; `DetachedAttachment` row gone
- [ ] Restore video → undiscarded, reappears, plays
- [ ] `OrphanBlobsCleanupJob` (run manually) does **not** purge the retained image blob; still purges a true orphan
- [ ] Non-owner contributor sees no remove button and gets 403/404 on the endpoints; feed shows no Restore for another's media
- [ ] Discarding the whole entry hides its videos too (cascade); restoring the entry is parent-only (videos stay discarded unless individually restored) — **confirm this is the intended UX**
- [ ] Dark mode; mobile; no console/network errors on any touched page

## 10. Validation Gates

```bash
mise x -- bundle exec rake project:fix-lint && mise x -- bundle exec rake project:lint
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
mise x -- env TEST_BROWSER=rack_test bundle exec rspec spec/system   # CI parity
```
- Overcommit: `RailsSchemaUpToDate` (run the two migrations before committing models), RuboCop, whitespace, subject rules. No `[skip ci]`.
- **Data-safety gate (load-bearing):** the `OrphanBlobsCleanupJob` exclusion spec **must** be green before merge — a regression here silently deletes user photos 24h later.

## 11. Rollback Plan

Additive and reversible. Revert UI commits → media is no longer removable (back to attach-only). Revert action/job/event commits → no per-item removal; existing media untouched. Migrations: `rails db:rollback` drops `detached_attachments` and the `discarded_at` column; no change to `journal_entries`/`active_storage_*` data. Any `DetachedAttachment` rows present at rollback leave their blobs detached — a one-off reconcile (re-attach or purge) is the only manual step; document it in Steps if it arises.

## 12. Open Risks

1. **Orphan-sweep exclusion (highest):** miss it and retained image blobs vanish in 24h. Mitigated by the §5.3 spec as a merge gate.
2. **Feed auditable wiring for two new types** extends the Phase-25 `build_restorable` contract — covered by request specs for both removed and restored states.
3. **Entry-discard → video cascade** changes existing behaviour (videos currently stay `kept` when an entry is discarded). Confirm the cascade + parent-only-restore UX in runtime (checklist §9).
4. **Image "which one" identity** via `signed_id` — validate the remove button targets the right blob when an entry has several images.

## 13. Quality Checklist
- [x] Exact precedent files + clone map (Phase 25 discard/restore, feed Restore, orphan job)
- [x] Two-mechanism architecture justified (video discard vs image `DetachedAttachment`)
- [x] The one irreversible risk (orphan sweep) isolated, specced, and gated
- [x] Decisions D1–D3 recorded from the owner
- [x] Executable validation gates + data-safety gate
- [x] Soft-only scope (no purge) explicit; purge deferred
