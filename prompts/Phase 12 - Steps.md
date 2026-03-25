# Phase 12: MCP Direct Image Upload Tool - Steps Taken

**Date:** 2026-03-25
**Branch:** `feature/mcp-direct-image-upload`
**Issue:** [#42](https://github.com/joel/trip/issues/42)
**PR:** [#43](https://github.com/joel/trip/pull/43)

---

## Step 1: Read Plan and Analyze Existing Patterns

- Read `prompts/Phase 12.md` for the implementation plan
- Read `PRPs/trip-journal.md` for project context
- Read existing `AttachImages` action, `AddJournalImages` MCP tool, `BaseTool`, `TripJournalServer`
- Read existing specs for both action and tool
- Verified Marcel gem available via ActiveStorage dependency
- Verified `spec/fixtures/files/test_image.jpg` exists for tests

## Step 2: Create UploadImages Action

**File:** `app/actions/journal_entries/upload_images.rb`

- Mirrors `AttachImages` structure with `BaseAction` + `Dry::Monads`
- Flow: `normalize_images` -> `validate_images` -> `validate_image_count` -> `decode_all` -> `attach_all` -> `emit_event`
- Key: `Base64.strict_decode64` for strict decoding, `Marcel::MimeType.for(StringIO.new(bytes))` for content type detection
- Constants: `MAX_IMAGES_PER_CALL = 5`, `MAX_IMAGES_PER_ENTRY = 20`, `MAX_FILE_SIZE = 10.megabytes`
- Custom `DecodeError` exception (analogous to `DownloadError` in AttachImages)
- Normalizes string keys to symbols (MCP gem only symbolizes top-level keys)
- Generates filenames from detected MIME when caller omits them

**Spec:** `spec/actions/journal_entries/upload_images_spec.rb` (10 examples)

## Step 3: Create UploadJournalImages MCP Tool

**File:** `app/mcp/tools/upload_journal_images.rb`

- Thin adapter following `AddJournalImages` pattern
- `input_schema` with `journal_entry_id` (string) and `images` (array of objects with `data` required, `filename` optional)
- Delegates to `JournalEntries::UploadImages` action
- Same error handling: `ToolError`, `RecordNotFound`, `Dry::Monads` pattern matching

**Spec:** `spec/mcp/tools/upload_journal_images_spec.rb` (5 examples)

## Step 4: Register Tool in TripJournalServer

**File:** `app/mcp/trip_journal_server.rb`

- Added `Tools::UploadJournalImages` to `TOOLS` array (11 -> 12 tools)
- Updated `INSTRUCTIONS` to mention direct upload capability

## Step 5: Update Existing Specs

- `spec/mcp/trip_journal_server_spec.rb`: Updated count from 11 to 12, added `Tools::UploadJournalImages` to expected list
- `spec/requests/mcp_spec.rb`: Updated count from 11 to 12, added `upload_journal_images` to tool name list

## Step 6: Lint and Tests

- `bundle exec rake project:fix-lint` -- no issues
- `bundle exec rake project:lint` -- 373 files inspected, no offenses detected
- `bundle exec rake project:tests` -- 478 examples, 0 failures, 2 pending
- RuboCop fixes applied: modifier `if` style, method length extraction (`validate_decoded!`), multiline call indentation

## Step 7: Git Workflow (Atomic Commits)

Three atomic commits on `feature/mcp-direct-image-upload`:

1. `cadeb40` - feat: Add UploadImages action for base64 image uploads
2. `d92b270` - feat: Add UploadJournalImages MCP tool for direct image upload
3. `251aae2` - feat: Register UploadJournalImages in MCP server (12 tools)

All overcommit hooks passed (RuboCop, TrailingWhitespace, FixMe, commit-msg checks).

## Step 8: GitHub Issue and PR

- Created issue [#42](https://github.com/joel/trip/issues/42) with label `enhancement`
- Pushed branch and created PR [#43](https://github.com/joel/trip/pull/43) referencing `Closes #42`

## Step 9: Product Review (Live Runtime Verification)

- `bin/cli app rebuild` -- succeeded, health check 200 OK
- `bin/cli mail start` -- running
- MCP endpoint verified: `tools/list` returns 12 tools including `upload_journal_images`
- End-to-end test: uploaded base64 JPEG to started trip journal entry -- success (`attached: 1, total_images: 3`)
- Guard test: upload to finished trip correctly rejected ("not writable")
- Key pages verified (home, login, health) -- all 200 OK
- Docker logs clean -- no errors or exceptions

## Step 10: PR Review Response

PR #43 received 2 Codex review comments:

1. **P1 (Pre-decode size guard):** Added `MAX_ENCODED_SIZE` constant and `data.bytesize` check before `Base64.strict_decode64` to reject oversized payloads without allocating decoded bytes. New spec added.
2. **P2 (Transactional attach):** Wrapped `attach_all` loop in `ActiveRecord::Base.transaction` so partial attaches are rolled back on storage errors.

Both fixes committed in `2618570`, pushed, replied to comments, and both review threads resolved.

## Files Created

| File | Lines | Purpose |
|------|-------|---------|
| `app/actions/journal_entries/upload_images.rb` | 120 | Core business logic for base64 image upload |
| `app/mcp/tools/upload_journal_images.rb` | 55 | MCP tool adapter |
| `spec/actions/journal_entries/upload_images_spec.rb` | 131 | Action specs (10 examples) |
| `spec/mcp/tools/upload_journal_images_spec.rb` | 67 | Tool specs (5 examples) |

## Files Modified

| File | Change |
|------|--------|
| `app/mcp/trip_journal_server.rb` | Added tool to TOOLS array, updated INSTRUCTIONS |
| `spec/mcp/trip_journal_server_spec.rb` | Updated count 11 -> 12, added tool to expected list |
| `spec/requests/mcp_spec.rb` | Updated count 11 -> 12, added tool name to expected list |

## Files Unchanged (Reused As-Is)

- `app/subscribers/journal_entry_subscriber.rb` -- handles `journal_entry.images_added`
- `app/jobs/process_journal_images_job.rb` -- generates variants
- `app/models/journal_entry.rb` -- `has_many_attached :images`
- `app/controllers/mcp_controller.rb` -- routes JSON-RPC
- `config/initializers/event_subscribers.rb` -- already subscribed
