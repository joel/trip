# QA Review -- feature/export-architecture

**Branch:** `feature/export-architecture`
**Phase:** 6 -- Export Architecture + Workflow Completion
**Date:** 2026-03-23
**Reviewer:** Claude (adversarial QA pass)

---

## Test Suite Results

- **Phase 6 specs:** 45 examples, 0 failures
- **Full test suite:** 373 examples, 0 failures, 2 pending (pre-existing)
- **Linting:** 336 files inspected, no offenses detected

---

## Acceptance Criteria

- [x] Export model with format enum (markdown, epub) and status enum (pending, processing, completed, failed) -- PASS
- [x] Exports scoped to trips, owned by users, with Active Storage file attachment -- PASS
- [x] ExportPolicy enforces member/superadmin access, respects trip.commentable? for creation -- PASS
- [x] ExportsController with index, new, create, show, download actions -- PASS
- [x] RequestExport action creates export and emits event -- PASS
- [x] ExportSubscriber listens for export.requested and enqueues GenerateExportJob -- PASS
- [x] GenerateExportJob uses ActiveJob::Continuable with 4 steps -- PASS
- [x] MarkdownGenerator produces ZIP with _index.md, entry files, and assets/ -- PASS
- [x] EpubGenerator produces valid .epub file -- PASS
- [x] HtmlToMarkdown converts ActionText rich text to Markdown -- PASS
- [x] ExportMailer sends notification when export completes -- PASS
- [x] ProcessJournalImagesJob generates image variants on journal_entry.created -- PASS
- [x] NotifyTripStateChangeJob sends email to all trip members on state change -- PASS
- [x] TripSubscriber and JournalEntrySubscriber wired to dispatch real jobs -- PASS
- [x] Sidebar nav highlights correctly for exports controller -- PASS
- [x] Trip show page links to exports -- PASS

---

## Defects (must fix before merge)

### D1: GenerateExportJob -- instance variable lost between Continuable steps

**File:** `app/jobs/generate_export_job.rb` lines 15-27

`@tempfile` is set in `step :generate_file` and consumed in `step :attach_file`. If the queue adapter signals `stopping?` between these two steps, the job is interrupted and resumed. On resume, the `generate_file` step is skipped (already completed), so `@tempfile` is nil. The `attach_file` step then calls `@tempfile.path` on nil, causing a `NoMethodError`.

Additionally, the Tempfile object itself would be garbage-collected between runs.

**Steps to reproduce:** This only occurs in production-like environments with a real queue adapter (Solid Queue) when the server is shutting down between steps 2 and 3. Not reproducible in test mode (inline adapter).

**Expected:** Export completes successfully after resumption.
**Actual:** Export fails with NoMethodError after resumption.

**Recommended fix:** Merge `generate_file` and `attach_file` into a single step, or persist the generated file to a known path (e.g., `Rails.root.join("tmp/exports/#{export_id}.*")`) instead of using a Tempfile.

### D2: GenerateExportJob -- no max_resumptions, infinite retry on persistent failures

**File:** `app/jobs/generate_export_job.rb`

`ActiveJob::Continuable` defaults to `max_resumptions: nil` (unlimited). Combined with `resume_errors_after_advancing: true` (default), any `StandardError` raised after step 1 (`mark_processing`) completes will be caught by Continuable's error handler, not by the job's own `rescue` block. The job will be retried indefinitely.

If the generator consistently fails (e.g., corrupt data, missing gem in production), the export stays in `processing` state forever, retrying every 5 seconds.

**Expected:** Export transitions to `failed` after a reasonable number of retries.
**Actual:** Export retries infinitely, staying in `processing` state.

**Recommended fix:** Add `self.max_resumptions = 5` (or similar) to the job class. Also consider whether the `rescue` block at line 32 needs to account for Continuable catching errors before it.

### D3: ExportsController#create -- NoMethodError on missing params

**File:** `app/controllers/exports_controller.rb` line 34

`params[:export][:format]` will raise `NoMethodError` if the `export` key is missing from the request params (`nil[:format]`). While this can only occur from a malicious or malformed request (not through the form), it should be handled gracefully.

**Steps to reproduce:** `POST /trips/:id/exports` with no body or with `params = { foo: "bar" }`.

**Expected:** A user-friendly error (e.g., redirect with alert).
**Actual:** 500 Internal Server Error.

**Recommended fix:** Use `params.dig(:export, :format)` or strong parameters (`params.require(:export).permit(:format)`).

---

## Edge Case Gaps (should fix or document)

### E1: No rate limiting on export creation

A user can create unlimited export requests by repeatedly submitting the form. Each request creates an Export record and enqueues a GenerateExportJob. With many concurrent exports, this could overwhelm the job queue and consume significant disk/memory for Tempfiles.

**Risk if left unfixed:** Resource exhaustion from a single user, intentional or accidental (double-click on submit button).

**Recommendation:** Either add a uniqueness constraint (one pending/processing export per user per trip per format) or throttle requests (e.g., max 3 per hour per user).

### E2: Unicode-only trip/entry names produce empty filenames

`String#parameterize` on a unicode-only string (e.g., Japanese characters) returns `""`. This results in:
- Export filenames like `.zip` or `.epub` (for trip names)
- Entry filenames like `2026-03-23-.md` (for entry names)
- Potential filename collisions between entries with same date and non-ASCII names

**Risk if left unfixed:** Confusing filenames; potential ZIP entry collisions causing data loss in exports.

**Recommendation:** Add a fallback: `name.parameterize.presence || "untitled"`.

### E3: N+1 query on exports index page

`ExportsController#index` uses `.includes(:user)` but does not eager-load the Active Storage `file` attachment. Each `ExportCard` component calls `@export.file.attached?`, triggering a separate query per export.

**Risk if left unfixed:** Slow page load for users with many exports. Low severity since exports are scoped per user per trip.

**Recommendation:** Add `.with_attached_file` to the query chain.

### E4: Invalid format enum value causes unhandled ArgumentError

If a tampered request sends `format: "pdf"`, `Export.create!(format: "pdf")` raises `ArgumentError` (from Rails enum). The `RequestExport` action only catches `ActiveRecord::RecordInvalid`, so this propagates as a 500 error.

**Risk if left unfixed:** 500 error on malformed requests. Low severity (requires tampering).

**Recommendation:** Add `rescue ArgumentError => e` in `RequestExport#persist` or validate the format before calling `create!`.

### E5: No cleanup mechanism for failed exports

When a `GenerateExportJob` fails, the Tempfile created by the generator is not cleaned up (no `ensure` block on the tempfile). Also, there is no UI or background job to delete old/failed Export records or their attachments.

**Risk if left unfixed:** Disk space leakage over time from abandoned Tempfiles and orphaned Active Storage blobs.

**Recommendation:** Add an `ensure` block in the job to clean up the Tempfile on failure. Consider a periodic cleanup job for failed exports older than N days.

### E6: Exports link on trip show page not gated by authorization

`app/views/trips/show.rb` line 58-62 renders an "Exports" button unconditionally. Non-members who can view the trip (if such a path exists) will see the link but get a 403 when clicking it.

**Risk if left unfixed:** Minor UX confusion. Low severity since trip show is itself gated by `TripPolicy`.

**Recommendation:** Wrap the link in `if view_context.allowed_to?(:index?, @trip, with: ExportPolicy)`.

### E7: Tempfile leak in generators on job failure

`MarkdownGenerator#call` and `EpubGenerator#call` each create a `Tempfile` and return it. If the `attach_file` step in `GenerateExportJob` fails, `@tempfile.close!` is never called. The GC finalizer will eventually clean it up, but this is not guaranteed or timely.

**Risk if left unfixed:** Temporary file accumulation on disk during periods of frequent failures.

---

## Observations

- **Policy consistency:** `ExportPolicy#create?` uses `(superadmin? || member?) && trip.commentable?` which is consistent with how `CommentPolicy` and `ReactionPolicy` handle the `commentable?` check. A superadmin who is not a member CAN create exports, which differs from comment/reaction policies where superadmin bypasses the membership check entirely. This appears intentional.

- **Export visibility:** Regular members can only see their own exports (both in index and show). Superadmins see all exports on the index. This is a good privacy design.

- **IDOR protection:** `set_export` scopes through `@trip.exports.find(params[:id])`, preventing cross-trip export access by UUID guessing. Authorization is checked in both show and download actions.

- **Download security:** The download action redirects to a signed Active Storage URL (`rails_blob_path`). The signed URL is time-limited by Active Storage defaults. This is standard and secure.

- **Event subscriber pattern:** The `ExportSubscriber` correctly uses `emit(event)` (not `call`), consistent with the Rails.event structured events pattern documented in CLAUDE.md.

- **Mailer resilience:** Both `ExportMailer` and `TripMailer` use `find_by` (returns nil) rather than `find` (raises), so deleted records won't cause mailer crashes. The `GenerateExportJob#send_notification` method also rescues and logs mailer errors without affecting the export status.

- **Test coverage:** Comprehensive specs cover model validations, policy authorization (including edge cases like removed membership), controller actions, job behavior (including failure scenarios), and generators. The policy specs notably test the "removed member can't see own export" edge case.

---

## Regression Check

- **Trip CRUD** -- PASS (routes, model, and controller unchanged except adding `has_many :exports`)
- **Authentication flows** -- PASS (no changes to Rodauth configuration or auth controllers)
- **Journal entries** -- PASS (subscriber now dispatches `ProcessJournalImagesJob` in addition to logging; the job uses `find_by` so missing entries are handled gracefully)
- **Comments and reactions** -- PASS (no changes to these features)
- **Sidebar navigation** -- PASS (`exports` added to the controller name list for "Trips" nav item highlighting)
