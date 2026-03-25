# Plan: MCP Direct Image Upload Tool

## Context

The MCP bot (Jack) can currently attach images to journal entries only via HTTPS URLs (`add_journal_images` tool). This requires images to be hosted on a third-party service first. We need a direct upload path so Jack can post image data directly without external hosting.

## Approach

Create a new MCP tool `upload_journal_images` that accepts base64-encoded image data inline in the JSON-RPC payload. Follows Open/Closed Principle: new tool + new action alongside existing ones, converging on the same downstream infrastructure (Active Storage, events, background jobs).

## Files to Create

### 1. `app/actions/journal_entries/upload_images.rb` — Core business logic

Mirrors `app/actions/journal_entries/attach_images.rb` structure:

```
call(journal_entry:, images:)
  -> validate_images(images)              # non-empty array, max 5
  -> validate_image_count(entry, images)  # current + new <= 20
  -> decode_all(images)                   # base64 decode, Marcel MIME sniff, size check
  -> attach_all(entry, staged)            # Active Storage attach
  -> emit_event(entry, count)             # "journal_entry.images_added" (same event)
  -> Success(journal_entry)
```

Key details:
- `Base64.strict_decode64` to reject malformed input
- `Marcel::MimeType.for(StringIO.new(bytes))` for content type detection (no trust in caller-declared type)
- Same constants: `ALLOWED_CONTENT_TYPES`, `MAX_IMAGES_PER_ENTRY = 20`, `MAX_FILE_SIZE = 10.megabytes`
- `MAX_IMAGES_PER_CALL = 5`
- Generate filename from detected MIME when caller omits it (`image_0.jpg`, `image_1.png`, etc.)
- Normalize image hashes to symbol keys (MCP gem only symbolizes top-level keys)
- Custom `DecodeError` (analogous to `DownloadError` in AttachImages)

### 2. `app/mcp/tools/upload_journal_images.rb` — MCP tool (thin adapter)

Mirrors `app/mcp/tools/add_journal_images.rb`:

```ruby
input_schema(
  properties: {
    journal_entry_id: { type: "string", description: "Journal entry UUID" },
    images: {
      type: "array",
      items: {
        type: "object",
        properties: {
          data: { type: "string", description: "Base64-encoded image data" },
          filename: { type: "string", description: "Original filename (optional)" }
        },
        required: %w[data]
      },
      description: "Images to upload (max 5 per call, max 10MB each, jpeg/png/webp/gif)"
    }
  },
  required: %w[journal_entry_id images]
)
```

Delegates to `JournalEntries::UploadImages`, same error handling pattern.

### 3. `spec/actions/journal_entries/upload_images_spec.rb`

Test cases: happy path, empty array, >5 images, exceeds 20 total, invalid base64, non-image content type (e.g. HTML), oversized file, event emission, provided filename used, generated filename from MIME.

### 4. `spec/mcp/tools/upload_journal_images_spec.rb`

Test cases: attaches and returns count, rejects non-writable trip, not-found entry, invalid base64, too many images.

## Files to Modify

### 5. `app/mcp/trip_journal_server.rb`

- Add `Tools::UploadJournalImages` to `TOOLS` array
- Update `INSTRUCTIONS` to mention direct upload capability

## Files Unchanged (reused as-is)

- `app/subscribers/journal_entry_subscriber.rb` — already handles `journal_entry.images_added`
- `app/jobs/process_journal_images_job.rb` — generates variants for any attached images
- `app/models/journal_entry.rb` — `has_many_attached :images`
- `app/controllers/mcp_controller.rb` — routes JSON-RPC unchanged
- `config/initializers/event_subscribers.rb` — already subscribed

## Implementation Order

1. Create action (`upload_images.rb`) + spec
2. Create MCP tool (`upload_journal_images.rb`) + spec
3. Register tool in `trip_journal_server.rb`
4. Lint + tests

## Verification

1. `bundle exec rake project:tests` — all specs pass
2. `bundle exec rake project:lint` — no violations
3. Manual MCP test via curl:
   ```
   echo -n <small_jpeg_bytes> | base64 → paste into JSON-RPC call
   POST /mcp with upload_journal_images tool call
   Verify image attached and variants generated
   ```
