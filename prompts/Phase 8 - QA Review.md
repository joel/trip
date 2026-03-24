# QA Review -- Phase 8: MCP Server Integration

**Branch:** `feature/phase-8-mcp-server-integration`
**Phase:** 8
**Date:** 2026-03-24
**Reviewer:** Claude (adversarial QA pass)

---

## Test Suite Results

- **Full test suite:** 409 examples, 0 failures, 2 pending
- **MCP-specific tests:** 33 examples, 0 failures
- **Linting:** 364 files inspected, no offenses detected

---

## Acceptance Criteria

- [x] All 10 MCP tools registered and callable via `tools/list` -- PASS
- [x] Authentication enforced via `MCP_API_KEY` Bearer token -- PASS
- [x] Missing API key returns 401 -- PASS
- [x] Wrong API key returns 401 -- PASS
- [x] Blank `MCP_API_KEY` env var returns 401 (safe default) -- PASS
- [x] `create_journal_entry` creates entry with actor attribution (`actor_type: "Jack"`, `actor_id: "jack"`) -- PASS
- [x] Active trip resolution works with exactly 1 started trip -- PASS
- [x] Active trip resolution returns error with 0 started trips -- PASS
- [x] Active trip resolution returns error with 2+ started trips (lists IDs) -- PASS
- [x] Idempotency: duplicate `telegram_message_id` on `create_journal_entry` returns existing record -- PASS
- [x] Idempotency: duplicate `telegram_message_id` on `create_comment` returns existing record -- PASS
- [x] Unique composite indexes enforce idempotency at DB level (`[trip_id, telegram_message_id]` and `[journal_entry_id, telegram_message_id]`) -- PASS
- [x] Partial unique indexes with `WHERE telegram_message_id IS NOT NULL` allow multiple NULL values -- PASS
- [x] `transition_trip` delegates to `Trips::TransitionState` and enforces valid transitions -- PASS
- [x] `toggle_checklist_item` toggles completion status correctly -- PASS
- [x] `list_journal_entries` supports pagination via `limit`/`offset` -- PASS
- [x] `list_checklists` returns nested sections and items with eager loading -- PASS
- [x] `get_trip_status` returns member count, entry count, checklist count -- PASS
- [x] `add_reaction` toggles (add/remove) correctly -- PASS
- [x] `update_journal_entry` and `update_trip` update and return updated data -- PASS
- [x] All tools delegate to existing Actions (no duplicated business logic) -- PASS
- [x] Jack system user created via `find_or_create_by!` with `email: "jack@system.local"`, `status: 2` (Rodauth verified) -- PASS
- [x] `McpController` inherits `ActionController::API`, not `ApplicationController` -- PASS (bypasses CSRF, sessions, Rodauth middleware, browser checks)
- [x] `mcp` gem explicitly in Gemfile (`~> 0.8`), locked at 0.8.0 -- PASS
- [x] No regressions in existing 376+ specs (now 409 total) -- PASS
- [x] `secure_compare` used for API key comparison (timing-attack safe) -- PASS

---

## Defects (must fix before merge)

### D1: MCP tools bypass trip state guards (`writable?` / `commentable?`)

**Files:**
- `app/mcp/tools/create_journal_entry.rb`
- `app/mcp/tools/update_journal_entry.rb`
- `app/mcp/tools/create_comment.rb`
- `app/mcp/tools/add_reaction.rb`
- `app/mcp/tools/toggle_checklist_item.rb`

**Steps to reproduce:**
1. Use `create_journal_entry` with `trip_id` pointing to a `cancelled` or `archived` trip.
2. The entry is created successfully.

**Expected:** Write operations should be rejected on non-writable trips. Comment/reaction operations should be rejected on non-commentable trips. The same business rules enforced by ActionPolicy in the web layer should be enforced in the MCP layer.

**Actual:** All write tools succeed on any trip regardless of state. The `writable?`/`commentable?` guards exist only in the policy layer (`app/policies/`), which MCP tools bypass by calling Actions directly.

**Impact matrix:**

| Tool | Guard Needed | Current Behavior |
|------|-------------|-----------------|
| `create_journal_entry` | `trip.writable?` | Creates on any trip |
| `update_journal_entry` | `trip.writable?` | Updates on any trip |
| `create_comment` | `trip.commentable?` | Comments on any trip |
| `add_reaction` | `trip.commentable?` | Reacts on any trip |
| `toggle_checklist_item` | `trip.writable?` | Toggles on any trip |
| `update_trip` | `trip.writable?` | Updates on any trip |

**Recommended fix:** Add guard checks in each tool before delegating to the Action. For example, in `CreateJournalEntry`:

```ruby
trip = resolve_trip(trip_id)
raise ToolError, "Trip '#{trip.name}' is not writable (state: #{trip.state})" unless trip.writable?
```

Alternatively, push the guards down into the Actions themselves so both the web and MCP layers enforce them consistently. This is the preferred long-term approach (fail at the domain layer, not the presentation layer).

---

### D2: N+1 query in `ListJournalEntries` -- `e.comments.size` per entry

**File:** `app/mcp/tools/list_journal_entries.rb:26`

**Steps to reproduce:**
1. Call `list_journal_entries` on a trip with 10+ entries, each having comments.
2. Observe one `SELECT COUNT(*)` query per entry.

**Expected:** A single query (or preloaded data) to count comments for all entries.

**Actual:** `e.comments.size` on an unloaded association issues a `SELECT COUNT(*) FROM comments WHERE journal_entry_id = ?` for each entry in the loop. With `limit: 10`, this means 10 extra queries. The commit history shows eager loading was attempted and reverted.

**Recommended fix:** Use a subquery or left join to fetch comment counts in a single query:

```ruby
entries = trip.journal_entries
              .chronological
              .left_joins(:comments)
              .select("journal_entries.*, COUNT(comments.id) AS comments_count_value")
              .group("journal_entries.id")
              .offset(offset)
              .limit(limit)
              .map do |e|
  {
    id: e.id, name: e.name, entry_date: e.entry_date.to_s,
    location_name: e.location_name, description: e.description,
    actor_type: e.actor_type, comments_count: e.comments_count_value
  }
end
```

Or add a `counter_cache: true` on the `Comment` model's `belongs_to :journal_entry`.

---

## Edge Case Gaps (should fix or document)

### E1: `RecordNotFound` from `resolve_trip` returns raw exception message

**Risk if left unfixed:** When a tool using `resolve_trip` (e.g., `CreateJournalEntry`, `ListJournalEntries`, `UpdateTrip`, `TransitionTrip`, `ListChecklists`, `GetTripStatus`) receives an invalid `trip_id`, `Trip.find(trip_id)` raises `ActiveRecord::RecordNotFound`. The MCP gem catches this at the server level and returns `"Internal error calling tool <name>: Couldn't find Trip with 'id'=<value>"`. This works but:
- The "Internal error" prefix implies a server bug rather than a user input error.
- The error is not marked with `error: true` in the MCP tool response schema in the same way as tools that explicitly rescue `RecordNotFound`.

**Recommendation:** Add `rescue ActiveRecord::RecordNotFound` to the `resolve_trip` method in `BaseTool`, raising `ToolError` with a friendly message. This makes the error consistent with other tool error handling:

```ruby
private_class_method def self.resolve_trip(trip_id)
  if trip_id.present?
    Trip.find(trip_id)
  else
    # ... existing logic
  end
rescue ActiveRecord::RecordNotFound
  raise ToolError, "Trip not found: #{trip_id}"
end
```

### E2: `transition_trip` with `resolve_trip` only finds `started` trips

**Risk if left unfixed:** A caller wanting to transition a `planning` trip to `started` must provide an explicit `trip_id`. Without it, `resolve_trip(nil)` searches only for `started` trips and returns "No active trip found." This is technically correct per the documented behavior ("optional if exactly one trip is started") but may confuse callers who expect the tool to find the trip they want to transition.

**Recommendation:** Document this limitation in the tool description. Consider accepting a `state` filter parameter in `resolve_trip` for tools that operate on non-started trips.

### E3: `update_trip` / `update_journal_entry` accept empty updates

**Risk if left unfixed:** Calling `update_trip` with no `name` or `description` parameters sends `params: {}` to the Action, which calls `trip.update!({})`. This is a no-op but generates an unnecessary DB transaction, event emission, and success response. Same for `update_journal_entry` with only `journal_entry_id`.

**Recommendation:** Add an early return or validation when no updatable params are provided:

```ruby
return error_response("No fields to update") if params.empty?
```

### E4: Inconsistent response helper naming across tools

**Risk if left unfixed:** Code maintainability suffers. Each tool uses different method names for the same concept:
- `tool_response` / `error_response` (`CreateJournalEntry`)
- `success_response` / `error_response` (`CreateComment`)
- `text_response` / `text_error` (`AddReaction`)
- `format_result` (`AddReaction`)
- Inline `MCP::Tool::Response.new(...)` (6 other tools)

**Recommendation:** Extract shared `success_response(data)` and `error_response(message)` methods into `BaseTool`. Each tool would then call `success_response({ id: ..., name: ... })` and `error_response("message")` consistently.

### E5: `create_journal_entry` sets `body` in a separate `update!` call

**Risk if left unfixed:** The ActionText `body` is set after the Action completes via `entry.update!(body: body)` (line 52). If this second write fails (e.g., database connectivity), the entry exists without its body. The entry creation event has already been emitted.

**Recommendation:** Pass `body` through the Action's params hash. The `has_rich_text :body` virtual attribute on `JournalEntry` supports assignment during `create!`. This would require modifying the Action to accept body, or restructuring the tool to pass it in params.

### E6: No rate limiting on MCP endpoint

**Risk if left unfixed:** The `/mcp` endpoint has no rate limiting. A compromised API key or runaway client could flood the endpoint with requests. The web layer benefits from Rack middleware and browser-based throttling, but the API endpoint has none.

**Recommendation:** Add `Rack::Attack` throttling for the `/mcp` path, keyed on the API key or IP address. This can be a follow-up task.

### E7: No test for `tools/call` through the HTTP endpoint

**Risk if left unfixed:** The request spec (`spec/requests/mcp_spec.rb`) tests `initialize` and `tools/list` through HTTP but does not test an actual `tools/call` through the full stack (HTTP -> controller -> MCP server -> tool -> Action -> database). Tool-level specs test the `.call` method directly, bypassing the HTTP/JSON-RPC layer.

**Recommendation:** Add at least one integration test that calls a tool through `POST /mcp` with a `tools/call` JSON-RPC request and verifies the database side effect.

---

## Observations

- **Clean architectural separation.** The MCP tools correctly delegate to existing Actions rather than reimplementing business logic. The `BaseTool` provides shared `resolve_trip` and `resolve_jack_user` helpers. Each tool is under 80 lines and has a single responsibility.

- **Controller choice is sound.** Inheriting from `ActionController::API` instead of `ApplicationController` is the right call. It avoids CSRF protection, session management, Rodauth middleware, `allow_browser` checks, and Phlex layout rendering -- none of which apply to a machine-to-machine API.

- **Idempotency implementation is robust.** The two-layer approach (application-level `find_by` + database-level unique index with `rescue RecordNotUnique`) correctly handles race conditions. The partial unique index (`WHERE telegram_message_id IS NOT NULL`) allows multiple records without a `telegram_message_id`.

- **Jack user creation is safe.** `find_or_create_by!` with `email: "jack@system.local"` and `status: 2` (Rodauth verified) ensures the system user is created once and reused. The `@system.local` domain clearly marks it as non-human.

- **MCP gem exception handling provides safety net.** The gem's `rescue => e` in `call_tool_with_args` (server.rb:425) catches any unhandled exception from tools and wraps it in an error tool response. This prevents 500 errors from reaching the HTTP layer, though the error messages are generic ("Internal error calling tool...").

- **Schema changes are minimal and backward-compatible.** Only one new column (`telegram_message_id` on `comments`) and two new indexes were added. The `actor_type`, `actor_id`, and `telegram_message_id` columns on `journal_entries` already existed from the initial table creation, showing good forward planning in Phase 3.

- **The stateless server-per-request pattern works with MCP gem 0.8.0.** The gem does not require an `initialize` handshake before processing `tools/list` or `tools/call`. Each request creates a fresh `MCP::Server` instance, which is simple and avoids session management complexity.

- **The `tools/list` test sends an unnecessary `initialize` request first** (mcp_spec.rb:71-73). Since each POST creates a new server, the initialize in the first request has no effect on the second. The test still passes because `tools/list` works without prior initialization, but the first POST is wasted work. Minor -- does not affect correctness.

---

## Regression Check

- **Trip CRUD** -- PASS (no models or controllers modified; routes only add `/mcp`)
- **Journal entries** -- PASS (model unchanged; new columns pre-existed in schema)
- **Authentication** -- PASS (Rodauth untouched; MCP uses separate auth path)
- **Comments & reactions** -- PASS (models unchanged; only new `telegram_message_id` column on comments, nullable)
- **Checklists** -- PASS (models unchanged; MCP tools delegate to existing Actions)
- **Exports** -- PASS (no changes to export logic)
- **Full test suite** -- PASS (409 examples, 0 failures)

---

## Summary

Phase 8 delivers a well-structured MCP server integration with 10 tools, Bearer token authentication, idempotency support, actor attribution, and active trip resolution. The implementation correctly delegates to existing Actions, uses appropriate Rails patterns (API controller, secure comparison, find_or_create_by), and has comprehensive test coverage (33 new specs).

**Two defects require attention before merge:**

1. **D1 (Critical):** MCP tools bypass trip state guards, allowing writes to cancelled/archived trips. This is the most important fix -- either add guards to each tool or push them into the Actions layer.

2. **D2 (Moderate):** N+1 query in `ListJournalEntries` will degrade performance as entries grow. Solvable with a left join, counter cache, or subquery.

**Seven edge case gaps are identified** (E1-E7), ranging from error message quality to missing integration tests. None are blockers, but E1 (RecordNotFound handling) and E4 (response helper consistency) should be addressed for code quality.
