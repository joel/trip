# UX Review — feature/phase-8-mcp-server-integration

**Date:** 2026-03-24
**Reviewer:** Claude Opus 4.6 (1M context)
**Scope:** API-only change -- MCP server at `POST /mcp`. No new UI pages or forms. This review focuses on API ergonomics, error messages, developer experience of the MCP tools, and consistency of the tool interface contract.

---

## Broken (blocks usability)

### B1: N+1 query in `ListJournalEntries` -- `e.comments.size`

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/mcp/tools/list_journal_entries.rb`, line 26

The `.map` block calls `e.comments.size` for every entry in the result set. Because there is no `.includes(:comments)` on the query chain, this fires one `SELECT COUNT(*)` per entry -- a classic N+1. For a trip with 50 entries and `limit: 50`, this produces 51 queries.

**Recommended fix:** Either add `.includes(:comments)` to the query chain (which loads all comment records into memory, wasteful if only the count is needed), or use `counter_cache: true` on the `has_many :comments` association, or use a `LEFT JOIN` with `GROUP BY` to compute counts in a single query. The simplest immediate fix:

```ruby
entries = trip.journal_entries
              .chronological
              .offset(offset)
              .limit(limit)
              .left_joins(:comments)
              .select("journal_entries.*, COUNT(comments.id) AS comments_count_value")
              .group("journal_entries.id")
```

Then use `e.comments_count_value` instead of `e.comments.size`.

### B2: N+1 queries in `GetTripStatus` -- three separate COUNT queries

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/mcp/tools/get_trip_status.rb`, lines 25-27

`trip.trip_memberships.count`, `trip.journal_entries.count`, and `trip.checklists.count` each issue a separate `SELECT COUNT(*)` query. While this is not an N+1 in the traditional sense (it is 3 queries total, not N), it is still suboptimal. If `GetTripStatus` is called frequently (e.g., by Jack on every interaction to check context), the three round-trips add up.

**Recommended fix:** This is a minor performance concern, not a blocker. Acceptable for Phase 8. Could consolidate into a single query in a follow-up if profiling shows it matters.

**Severity adjustment:** Reclassified to **Friction** -- the 3 queries are bounded and predictable, not truly blocking usability.

---

## Friction (degrades experience)

### F1: No Content-Type validation on incoming requests

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/controllers/mcp_controller.rb`

The controller reads `request.body.read` and passes it to `server.handle_json()` without verifying that the request has `Content-Type: application/json`. If a client sends `Content-Type: text/plain` or `multipart/form-data`, the body may still parse (or may produce a confusing error from the MCP gem's JSON parser). The MCP spec requires `application/json` for JSON-RPC requests.

**Recommended fix:** Add a `before_action` or guard at the top of `handle`:

```ruby
before_action :require_json_content_type!

def require_json_content_type!
  return if request.content_type&.start_with?("application/json")

  head :unsupported_media_type
end
```

### F2: No rescue for malformed JSON

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/controllers/mcp_controller.rb`

If the request body is not valid JSON (e.g., truncated, binary garbage), `server.handle_json` will likely raise a `JSON::ParserError` (or equivalent from the MCP gem). Without a `rescue`, this surfaces as a 500 Internal Server Error with a Rails error page or stack trace -- unhelpful for an API client.

**Recommended fix:** Add a rescue clause:

```ruby
def handle
  server = TripJournalServer.build(server_context: { request_id: request.uuid })
  render json: server.handle_json(request.body.read)
rescue JSON::ParserError
  render json: {
    jsonrpc: "2.0", id: nil,
    error: { code: -32700, message: "Parse error" }
  }, status: :ok
end
```

The JSON-RPC spec defines error code `-32700` for parse errors. The HTTP status should be 200 per JSON-RPC convention (the error is in the response body), though 400 is also acceptable for non-JSON payloads.

### F3: Stateless server instantiation on every request

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/controllers/mcp_controller.rb`, line 7

`TripJournalServer.build` creates a new `MCP::Server` instance on every request. This means the MCP `initialize` handshake is not persisted -- the server has no memory of whether the client already initialized. The `tools/list` test in the request spec sends `initialize` first, then `tools/list` in a second request, but each hits a fresh server instance.

Whether this works depends on whether the MCP gem's `handle_json` requires a prior `initialize` call or handles each request statelessly. The tests pass, so the gem appears to tolerate it, but this is fragile if the gem later enforces session state. The Phase 8 plan explicitly chose "stateless JSON-RPC" (Key Design Decision #2), so this is intentional. However, the MCP specification (2025-03-26) describes `initialize` as a required first step in a session.

**Recommended fix:** Document this as a known limitation. If MCP clients start failing because they expect session persistence, add server-side session caching keyed by a client-provided session ID. No action needed now, but worth a comment in the code.

### F4: `TransitionTrip` tool description does not document valid transitions

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/mcp/tools/transition_trip.rb`, line 10

The `new_state` parameter description says `"Target state: started, finished, cancelled, archived, planning"` -- listing all states. But not all transitions are valid from every state (e.g., `started -> archived` is invalid; only `started -> finished` or `started -> cancelled` are allowed). An AI client calling this tool has no way to know which transitions are valid without first calling `get_trip_status` and knowing the state machine.

**Recommended fix:** Enhance the description to mention that only certain transitions are valid, or better yet, include the transition map in the tool description:

```
"Valid transitions: planning -> started/cancelled, started -> finished/cancelled,
finished -> archived, cancelled -> planning. Archived is terminal."
```

Alternatively, add a `get_valid_transitions` field to the `get_trip_status` response so the AI can check programmatically.

### F5: `UpdateTrip` allows calling with no update params

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/mcp/tools/update_trip.rb`

The `input_schema` has no `required` fields. A caller can invoke `update_trip` with only `trip_id` (or even nothing, relying on active trip resolution) and no `name` or `description`. The `.compact` call produces an empty hash, which gets passed to `Trips::Update`. Depending on the action's behavior, this either succeeds as a no-op (with an event emitted for nothing) or raises an error. Either way, it is a confusing experience.

**Recommended fix:** Either add validation that at least one of `name` or `description` is present, or document clearly that calling with no update params is a no-op. A guard at the top of `self.call` would be clearest:

```ruby
return error_response("At least one of name or description must be provided") if params.empty?
```

### F6: Inconsistent error response patterns across tools

Multiple tools define their own `error_response` / `text_error` private methods with slightly different signatures and behaviors:

- `CreateJournalEntry.error_response(errors)` -- handles both `ActiveModel::Errors` and strings
- `AddReaction.text_error(message)` -- only handles strings
- `UpdateTrip` -- inline error construction, no extracted method
- `TransitionTrip` -- inline error construction
- `GetTripStatus`, `ListChecklists`, `ListJournalEntries` -- inline error construction

This means error formatting is inconsistent. Some tools return `{ "text": "error message" }` with `error: true`, while others might return `{ "text": "Name can't be blank, Entry date can't be blank" }`. There is no standard error envelope.

**Recommended fix:** Extract a shared `error_response` method into `BaseTool` so all tools use the same error formatting:

```ruby
class BaseTool < MCP::Tool
  private_class_method def self.error_response(errors)
    message = case errors
              when ActiveModel::Errors then errors.full_messages.join(", ")
              else errors.to_s
              end
    MCP::Tool::Response.new([{ type: "text", text: message }], error: true)
  end
end
```

### F7: `CreateJournalEntry` body is set via a second `update!` call, not via the Action

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/mcp/tools/create_journal_entry.rb`, line 53

The `create_entry` method calls `JournalEntries::Create.new.call(params:, trip:, user:)` and then does `entry.update!(body: body) if body.present?` separately. This bypasses the Action pattern -- the body update does not go through the Action, does not emit an event, and could fail independently (leaving a half-created entry with no body).

The same pattern appears in `UpdateJournalEntry` (line 36).

This is likely because `body` is a `has_rich_text` field (Action Text) that cannot be set via the Action's `create!` params hash. If that is the case, this is a reasonable workaround but should be documented with a comment explaining why.

**Recommended fix:** Add a comment explaining the two-step creation:

```ruby
# body is an Action Text rich text field, set separately from the create! call
entry.update!(body: body) if body.present?
```

### F8: `resolve_trip` uses `started.count` then `started.first` -- two queries

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/mcp/tools/base_tool.rb`, lines 11-12

`started.count` fires a `SELECT COUNT(*)` and then `started.first` fires a separate `SELECT * ... LIMIT 1`. These could be combined into a single `started.to_a` (since we know there will be 0, 1, or a small number), then check `.size` on the array.

**Recommended fix:**

```ruby
started = Trip.where(state: :started).to_a
case started.size
when 1 then started.first
when 0 then raise ToolError, "No active trip found..."
else ...
end
```

This reduces from 2 queries to 1 for the common case.

---

## Suggestions (nice to have)

### S1: Add a `list_trips` tool

The current tool set has no way for Jack to discover which trips exist. If active trip resolution fails (0 or 2+ started trips), the error message includes IDs but Jack has no tool to list all trips with their states. Adding a `list_trips` tool (even read-only, returning `id`, `name`, `state`) would improve the developer/AI experience significantly.

### S2: Add `created_at` to tool responses

Tool responses for `create_journal_entry`, `create_comment`, etc. include `id`, `name`, and domain fields but not `created_at`. Including timestamps in responses helps an AI client confirm when something was created and reason about ordering.

### S3: Consider adding request logging for MCP calls

Since `McpController` extends `ActionController::API`, standard Rails request logging applies. However, the JSON-RPC method name (e.g., `tools/call`, `initialize`) is buried in the request body and not visible in standard logs. Adding a log line like `Rails.logger.info("MCP: #{parsed['method']}")` would make debugging and auditing much easier.

### S4: Add `enum` constraint to `new_state` in `TransitionTrip` input schema

The `new_state` parameter is typed as `string` with no `enum` constraint. Adding `enum: %w[planning started finished cancelled archived]` to the JSON Schema would let MCP clients validate inputs before sending, and would appear in `tools/list` output for self-documenting tools.

### S5: Add `enum` constraint to `emoji` in `AddReaction` input schema

Similarly, if the application has a fixed set of allowed emojis, listing them in the schema (or at least documenting the constraint in the description) would prevent trial-and-error by AI clients.

### S6: Consider `description` field naming collision in `CreateJournalEntry`

The `CreateJournalEntry` input schema has a parameter named `description` (for the journal entry's short summary). This collides with the MCP `Tool.description` class method name conceptually, and could confuse AI clients that interpret `description` as metadata about the tool rather than a data field. Renaming to `summary` would be clearer, though this would require a corresponding model change.

### S7: `resolve_jack_user` creates user with hardcoded `status: 2`

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/mcp/tools/base_tool.rb`, line 26

The magic number `2` represents Rodauth's "verified" account status. Using the Rodauth constant would be more maintainable, but since this code runs outside a Rodauth context, the literal is acceptable. A comment documenting the magic number would help future readers.

### S8: Consider rate limiting for the `/mcp` endpoint

The `/mcp` endpoint has no rate limiting. While Bearer token auth prevents unauthorized access, a compromised or misbehaving client could flood the endpoint. This is an infrastructure concern more than a code concern, but worth noting for production deployment.

### S9: `CreateJournalEntry` `RecordNotUnique` rescue may mask non-idempotency errors

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/mcp/tools/create_journal_entry.rb`, lines 57-59

The `rescue ActiveRecord::RecordNotUnique` block assumes the uniqueness violation is on `[trip_id, telegram_message_id]` and looks up the existing entry. If a different unique constraint is violated (e.g., a future unique index on `[trip_id, name, entry_date]`), this rescue would silently return the wrong record or raise `RecordNotFound`.

**Recommended fix:** Check which constraint was violated, or narrow the rescue to only handle the expected case. At minimum, add a comment noting the assumption.

### S10: Spec coverage for edge cases could be broader

The specs cover the happy path and key error paths well. Some gaps:

- No spec for `UpdateTrip` with empty params (the F5 friction item)
- No spec for `TransitionTrip` with an invalid `new_state` value (e.g., `"flying"`)
- No spec for `CreateJournalEntry` with a missing required field (e.g., no `name`)
- No spec for concurrent idempotency (two requests racing with same `telegram_message_id`)
- No spec for `ListJournalEntries` with `limit: 0` or negative offset

---

## Checklist (adapted for API-only change)

### API Ergonomics
- [x] All 10 tools registered and listed via `tools/list`
- [x] Tool names follow consistent `verb_noun` convention
- [x] Tool descriptions are clear and concise
- [ ] Valid transitions documented in `TransitionTrip` description (F4)
- [ ] `enum` constraints on bounded string inputs like `new_state` (S4)
- [x] Pagination supported on list endpoints (`limit`, `offset`)
- [x] Active trip resolution works as designed (0, 1, 2+ cases)
- [x] Idempotency via `telegram_message_id` works for creates

### Error Messages
- [x] Auth failure returns 401 (no API key, wrong key, blank env var)
- [x] "Not found" errors include the requested ID for debugging
- [x] Active trip ambiguity error lists the conflicting trip IDs
- [x] Invalid transition error includes from/to states
- [ ] Malformed JSON returns a proper JSON-RPC parse error (F2)
- [ ] Content-Type validation returns 415 (F1)
- [ ] No-op update (empty params) handled gracefully (F5)

### Developer Experience
- [x] Tool input schemas have clear descriptions on each parameter
- [x] Required vs optional parameters correctly declared
- [x] Default values documented in schema (`actor_type: "Jack"`, `limit: 10`)
- [x] Server instructions describe Jack's role
- [ ] Error response format consistent across all tools (F6)
- [ ] Valid state transitions discoverable without external docs (F4)

### Security
- [x] Bearer token auth with timing-safe comparison
- [x] Blank `MCP_API_KEY` env var rejects all requests (safe default)
- [x] Controller extends `ActionController::API` (no session, no CSRF)
- [x] No user-facing routes exposed (API only)

### Data Integrity
- [x] Unique partial indexes on `[trip_id, telegram_message_id]` and `[journal_entry_id, telegram_message_id]`
- [x] Race condition on idempotency handled via `rescue ActiveRecord::RecordNotUnique`
- [x] Jack system user created idempotently via `find_or_create_by!`
- [x] All write tools delegate to existing Actions (events emitted)

---

## Summary

Phase 8 delivers a well-structured MCP server with 10 tools, proper Bearer token authentication, idempotency support, and active trip resolution. The implementation correctly delegates to existing Actions, maintaining the project's architectural consistency.

The most impactful issues are the N+1 query in `ListJournalEntries` (B1), the missing Content-Type and malformed-JSON guards on the controller (F1, F2), and the inconsistent error response formatting across tools (F6). The N+1 will degrade performance as trip data grows. The controller guards are standard API hygiene that will prevent confusing error responses for misbehaving clients.

The friction items around tool descriptions (F4) and input validation (F5) affect the AI client's ability to self-serve without external documentation -- important for an MCP server whose primary consumers are language models.

No UI pages, forms, navigation, or visual elements were changed. The standard UX checklist items for flow, accessibility, responsiveness, and dark mode are not applicable to this phase.

---

## Screenshots reviewed

Not applicable -- Phase 8 is an API-only change with no UI surfaces.
