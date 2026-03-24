# Phase 10: MCP Image Attachment

## Context

Phases 1-9 are complete. The MCP server has 11 tools (after Phase 9 hardening), and the Telegram bot (Jack) is live and creating journal entries in production. However, the bot cannot attach photos — the MCP server only handles text fields. The bot sends image URLs from Telegram, but there's no tool to download and attach them.

The codebase already has a proven pattern for URL-based image attachment: `db/seeds.rb` uses `URI.open` + `record.images.attach(io:, filename:, content_type:)` to download from picsum.photos and attach to journal entries.

**Goal:** Add an `add_journal_images` MCP tool that accepts an array of image URLs, downloads them server-side, and attaches them to an existing journal entry via Active Storage.

**Issue:** To be created on GitHub (joel/trip)

---

## Scope

### 1. New Action: `JournalEntries::AttachImages`

- **File:** `app/actions/journal_entries/attach_images.rb`
- Follows the standard `BaseAction` pattern (Dry::Monads, persist + emit)
- Downloads images from URLs using `URI.open` (same as seeds)
- Validates: URL count, HTTPS scheme, content type, file size, total image count
- Attaches via `journal_entry.images.attach(io:, filename:, content_type:)`
- Emits `journal_entry.images_added` event

**Validation limits:**

| Constraint | Value | Rationale |
|-----------|-------|-----------|
| Max URLs per call | 5 | Prevents abuse; typical Telegram sends 1-3 photos |
| Max file size per image | 10 MB | Reasonable for photos; prevents memory pressure |
| Max total images per entry | 20 | Generous but bounded |
| Allowed content types | `image/jpeg`, `image/png`, `image/webp`, `image/gif` | Common web image types |
| URL scheme | HTTPS only | SSRF mitigation |
| Open timeout | 5 seconds | Matches seeds pattern |
| Read timeout | 15 seconds | Generous for larger photos |

**Action flow:**
```
call(journal_entry:, urls:)
  -> validate_urls(urls)           # count, scheme, format
  -> validate_image_count(entry)   # total won't exceed 20
  -> download_and_attach(entry)    # URI.open + images.attach
  -> emit_event(entry, count)      # journal_entry.images_added
  -> Success(entry)
```

**Error handling:** Same rescue set as seeds — `OpenURI::HTTPError`, `SocketError`, `Errno::ECONNREFUSED`, `Timeout::Error`, `URI::InvalidURIError`. Per-URL errors collected and returned as `Failure`.

### 2. New MCP Tool: `Tools::AddJournalImages`

- **File:** `app/mcp/tools/add_journal_images.rb`
- Follows the `CreateComment` pattern (operates on existing journal entry)
- Input schema accepts `journal_entry_id` (string) and `urls` (array of strings)
- Guards: `require_writable!(entry.trip)` — images can only be added to planning/started trips
- Delegates to `JournalEntries::AttachImages` action

```ruby
input_schema(
  properties: {
    journal_entry_id: {
      type: "string",
      description: "Journal entry UUID"
    },
    urls: {
      type: "array",
      items: { type: "string" },
      description: "Image URLs to attach (HTTPS only, max 5)"
    }
  },
  required: %w[journal_entry_id urls]
)
```

**Response:**
```json
{
  "journal_entry_id": "...",
  "attached": 3,
  "total_images": 5
}
```

### 3. Subscriber Update

- **File:** `app/subscribers/journal_entry_subscriber.rb`
- Add `journal_entry.images_added` case
- Reuses existing `ProcessJournalImagesJob` (it's idempotent — `.processed` skips already-processed variants)

### 4. Server Registration

- **File:** `app/mcp/trip_journal_server.rb`
- Add `Tools::AddJournalImages` to `TOOLS` array (10 → 11 tools)
- Update `INSTRUCTIONS` to mention image attachment capability

---

## Files to Create (~4)

| File | Purpose |
|------|---------|
| `app/actions/journal_entries/attach_images.rb` | Download URLs, validate, attach via Active Storage |
| `app/mcp/tools/add_journal_images.rb` | MCP tool wrapper |
| `spec/actions/journal_entries/attach_images_spec.rb` | Action unit tests |
| `spec/mcp/tools/add_journal_images_spec.rb` | Tool integration tests |

## Files to Modify (~4)

| File | Change |
|------|--------|
| `app/subscribers/journal_entry_subscriber.rb` | Add `journal_entry.images_added` event handler |
| `app/mcp/trip_journal_server.rb` | Register tool #11, update instructions |
| `spec/mcp/trip_journal_server_spec.rb` | Update tool count 10 → 11, add to expected list |
| `spec/requests/mcp_spec.rb` | Add `add_journal_images` to expected tool list |

---

## Key Design Decisions

1. **Standalone tool, not an extension of `create_journal_entry`** — The Telegram bot workflow sends text first, then images as separate messages. A standalone tool maps naturally to this interaction pattern and follows SRP.

2. **Synchronous download with strict timeouts** — The MCP caller needs immediate feedback on success/failure. The seeds already prove `URI.open` with timeouts works reliably. Async would leave the caller with no error feedback.

3. **New event `journal_entry.images_added`** — More semantically precise than reusing `journal_entry.created` or `journal_entry.updated`. Allows targeted variant processing.

4. **Reuse `ProcessJournalImagesJob` as-is** — The job iterates all images and calls `.processed`, which is idempotent. No need to track which blobs are new.

5. **No `remove_journal_images` tool (YAGNI)** — Can be added later if needed.

---

## Risks

1. **SSRF via URL downloads** — Mitigated by HTTPS-only restriction and content-type validation. Private IP blocking could be added but is not in scope for V1.

2. **Memory pressure from large downloads** — `URI.open` uses `Tempfile` for files > 10KB (Ruby stdlib behavior), so large images don't stay in memory. The 10MB size limit provides additional protection.

3. **Slow downloads blocking MCP response** — 15-second read timeout per image × 5 images = worst case 75 seconds. Acceptable for a bot workflow, and the timeouts will fail fast for unreachable URLs.

4. **`URI.open` in Ruby 4.0.1** — Part of stdlib (`open-uri`), should work unchanged. Verified by seed data usage in production.

---

## Verification

### Automated Tests
```bash
mise x -- bundle exec rspec spec/actions/journal_entries/attach_images_spec.rb
mise x -- bundle exec rspec spec/mcp/tools/add_journal_images_spec.rb
mise x -- bundle exec rspec spec/mcp/ spec/requests/mcp_spec.rb
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
mise x -- bundle exec rake project:lint
mise x -- bundle exec brakeman -q
```

### Runtime Verification
- [ ] Bot sends image URL → `tools/call add_journal_images` → 200 OK with attached count
- [ ] Image appears on journal entry show page in browser
- [ ] Variant processing job runs (check logs for `ProcessJournalImagesJob`)
- [ ] Non-HTTPS URL → rejected with clear error
- [ ] Non-image URL → rejected with content type error
- [ ] Invalid journal_entry_id → "Journal entry not found" error
- [ ] Non-writable trip → "Trip is not writable" error
- [ ] All existing tests still pass
- [ ] No Bullet N+1 alerts

### Definition of Done
- [ ] `add_journal_images` tool registered and callable via MCP
- [ ] Images download from HTTPS URLs and attach to journal entries
- [ ] Input validation enforced (URL count, scheme, content type, size)
- [ ] Variant processing triggered for new images
- [ ] Error responses are actionable (identify which URL failed and why)
- [ ] 11 tools listed in `tools/list` response
- [ ] All specs pass, lint clean, Brakeman clean
