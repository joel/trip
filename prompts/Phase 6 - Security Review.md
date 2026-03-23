# Security Review -- feature/export-architecture

**Date:** 2026-03-23
**Branch:** `feature/export-architecture`
**Scope:** Phase 6 -- Export Architecture + Workflow Completion
**Reviewer:** Automated adversarial security review

---

## Critical (must fix before merge)

### 1. Missing strong parameters on export creation

**File:** `app/controllers/exports_controller.rb:34`
**Issue:** The `create` action accesses `params[:export][:format]` directly without using `params.expect` or `params.require(...).permit(...)`. Every other controller in the codebase uses `params.expect` for parameter extraction. While the underlying `Export.create!` will raise `ArgumentError` for invalid enum values, bypassing strong parameters breaks the project convention and skips the Rails parameter filtering layer.

**Fix:** Add a private `export_params` method using `params.expect(export: [:format])` and use it in the `create` action.

### 2. Unhandled `ArgumentError` from invalid enum value

**File:** `app/actions/exports/request_export.rb:14` / `app/controllers/exports_controller.rb:30-43`
**Issue:** If a user submits a `format` value outside the defined enum (`markdown`, `epub`) -- for example `"pdf"` or an empty string -- `Export.create!` raises `ArgumentError` (not `ActiveRecord::RecordInvalid`). The `RequestExport` action only rescues `RecordInvalid`, so the `ArgumentError` propagates to the controller as an unhandled 500 error. An attacker can trigger 500 errors at will by POSTing `export[format]=bogus`.

**Fix:** Either (a) validate `format` in the controller before passing to the action, or (b) rescue `ArgumentError` in the `persist` method and return a `Failure`. Option (b) is more defensive:

```ruby
def persist(trip, user, format)
  export = Export.create!(trip: trip, user: user, format: format)
  Success(export)
rescue ActiveRecord::RecordInvalid => e
  Failure(e.record.errors)
rescue ArgumentError
  Failure(ActiveModel::Errors.new(Export.new).tap { |e| e.add(:format, :invalid) })
end
```

---

## Warning (should fix or consciously accept)

### 3. No rate limiting on export creation

**File:** `app/controllers/exports_controller.rb` (create action) / `app/jobs/generate_export_job.rb`
**Issue:** There is no rate limit on how many exports a user can request. An authenticated user could spam the endpoint and queue hundreds of `GenerateExportJob` jobs, each of which reads all journal entries, opens all image blobs, and generates a ZIP or ePub file. This constitutes a denial-of-service vector against the job queue and storage backend.

**Mitigation options:**
- Add a database-level uniqueness constraint or application check: prevent creating a new export while another is `pending` or `processing` for the same trip+user+format.
- Add a per-user cooldown (e.g., max 1 export request per minute).

### 4. ZIP entry filenames derived from user input without sanitization

**File:** `app/services/exports/markdown_generator.rb:128-131` (entry_slug), `:95` (blob.filename)
**Issue:** The `entry_slug` method uses `entry.name.parameterize`, which is safe for path traversal. However, `blob.filename` (line 95, `assets/#{blob.filename}`) comes from the original uploaded filename. While Active Storage sanitizes filenames to a degree, filenames with unusual characters could cause issues in ZIP readers. This is low risk because Active Storage's `ActiveStorage::Filename` sanitizes most problematic characters, but a defensive `sanitize` or `parameterize` call would be more robust.

### 5. Tempfile cleanup on job failure

**File:** `app/jobs/generate_export_job.rb:16-27`
**Issue:** If the job fails after the `generate_file` step but before or during `attach_file` (line 20-27), `@tempfile.close!` never runs. The tempfile will persist on disk until Ruby's finalizer garbage-collects the object, which may not happen promptly in a long-running worker process. Under sustained failure conditions this could fill disk.

**Mitigation:** Wrap the tempfile usage in an `ensure` block, or use `Tempfile.create` with a block.

### 6. `XhtmlWrapper` inserts body_html without escaping

**File:** `app/services/exports/xhtml_wrapper.rb:19`
**Issue:** The `@body_html` is inserted directly into the XHTML template without escaping. The `title` is properly escaped (line 16), but `body_html` is not. This is by design -- it contains processed HTML content for the ePub chapter. However, the HTML originates from Action Text (rich text) which is sanitized by Rails, and the `process_html` method in `EpubGenerator` uses `CGI.escapeHTML` on user-provided text like entry name and author. The risk is low because the output is a local ePub file (not rendered in a browser context with user cookies), but if the ePub is ever served inline, the unescaped HTML could carry XSS payloads embedded in rich text.

**Recommendation:** Accept consciously. The ePub is downloaded as an attachment (`disposition: "attachment"`) and the content comes from Action Text which has its own sanitizer.

---

## Informational (no action required)

### 7. Index action control flow is correct but reads confusingly

**File:** `app/controllers/exports_controller.rb:10-12`
**Observation:** Line 10 assigns `@exports` to user-scoped results. Line 12 conditionally overwrites for superadmins. This is functionally correct (non-superadmins see only their own exports; superadmins see all), but the two sequential assignments without an explicit `if/else` are easy to misread. Consider refactoring to an explicit `if/else` for clarity.

### 8. "Exports" link in trip show view has no policy gate

**File:** `app/views/trips/show.rb:58-62`
**Observation:** The "Exports" link is shown to all users on the trip show page without an `allowed_to?` check. This is consistent with how "Members" and "Checklists" links are rendered in the same view -- they also have no policy gate. Authorization is enforced at the controller level. Non-members clicking the link get a 403. This is the established pattern.

### 9. Active Storage blob URLs are signed and time-limited

**File:** `app/controllers/exports_controller.rb:54-56`
**Observation:** The `download` action redirects to `rails_blob_path` with `disposition: "attachment"`. Active Storage generates signed, time-limited URLs by default, so a leaked download URL expires. The `allow_other_host: true` is required for storage services on different hosts and does not introduce an open-redirect risk because the URL is generated server-side from a trusted blob reference.

### 10. New gems added

**File:** `Gemfile`
**Observation:** Two new gems added: `reverse_markdown` (HTML-to-Markdown conversion) and `rubyzip` (ZIP generation). `gepub` was already present. Both are well-maintained, widely-used gems. No known vulnerabilities at time of review, but they should be included in regular dependency auditing (e.g., `bundle audit`).

### 11. Export subscriber dispatches job without re-validating authorization

**File:** `app/subscribers/export_subscriber.rb:7`
**Observation:** The subscriber calls `GenerateExportJob.perform_later` based solely on the event payload, without re-checking authorization. This is acceptable because authorization was already enforced at the controller level before the event was emitted. The subscriber trusts the event as an already-authorized command.

### 12. Export model does not validate status presence

**File:** `app/models/export.rb`
**Observation:** The model validates `format` presence but not `status`. This is fine because `status` has a database default of `0` (pending) and is managed by the job, not by user input.

---

## Not applicable

| Category | Reason |
|---|---|
| **Invitation/token flows** | No tokens or invitation flows in this diff. |
| **File upload validation (type/size)** | Exports generate files server-side; no user file upload is introduced. Existing image uploads are unchanged. |
| **Raw SQL fragments** | No raw SQL in the diff. All queries use ActiveRecord methods. |
| **Secrets/credentials in code** | No hardcoded secrets, tokens, or credentials found. No `.env` files in the diff. |
| **Webauthn/Passkey changes** | No authentication mechanism changes. |

---

## Summary

| Severity | Count |
|---|---|
| Critical | 2 |
| Warning | 4 |
| Informational | 6 |
| N/A | 5 |

The two critical findings are straightforward fixes: add strong parameters and handle the `ArgumentError` from invalid enum values. The warnings relate to rate limiting (denial of service) and defensive coding in file generation, none of which are exploitable for data access.
