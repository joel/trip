# Phase 8: MCP Server Integration

## Context

Phases 1-7 are complete. The application has full trip journaling, comments, reactions, checklists, exports, event-driven workflows, and PWA support. The codebase has 376+ specs passing, comprehensive seed data, and a deployed production instance.

The `mcp` gem (0.8.0) is already in Gemfile.lock (transitive dependency). It provides `MCP::Server` with `define_tool`, `MCP::Tool` class-based definitions, and `StreamableHTTPTransport` for HTTP integration. All domain Actions exist in `app/actions/` and are ready to be exposed as MCP tools.

**Goal:** Expose the Trip Journal's domain actions as an MCP server so an AI assistant (Jack) can create journal entries, manage trips, toggle checklists, and query trip status via the Model Context Protocol.

**Issue:** To be created on GitHub (joel/trip)

---

## Scope

### MCP Server Setup
- **Add `mcp` gem explicitly to Gemfile** (currently transitive only)
- **Create `TripJournalMcpServer`** — an `MCP::Server` instance with all tools registered
- **Mount Streamable HTTP transport** at `/mcp` via a Rails controller that delegates to the MCP server
- **Authentication** — shared secret via `MCP_API_KEY` env var, validated on every request
- **Server instructions** — describe Jack's role and available capabilities

### MCP Tools (10 tools from PRP Section 7)

| Tool | Delegates to | Description |
|------|-------------|-------------|
| `create_journal_entry` | `JournalEntries::Create` | Create entry with actor attribution |
| `update_journal_entry` | `JournalEntries::Update` | Update entry name, body, date, location |
| `list_journal_entries` | Read-only query | Paginated entries for a trip |
| `create_comment` | `Comments::Create` | Add comment to a journal entry |
| `add_reaction` | `Reactions::Toggle` | Toggle emoji reaction |
| `update_trip` | `Trips::Update` | Update trip name, description |
| `transition_trip` | `Trips::TransitionState` | Start, finish, cancel a trip |
| `toggle_checklist_item` | `ChecklistItems::Toggle` | Toggle checklist item completion |
| `list_checklists` | Read-only query | List checklists with sections and items |
| `get_trip_status` | Read-only query | Current state, dates, member count, entry count |

### Actor Attribution
- All write tools accept `actor_type` (default: `"Jack"`) and `actor_id` (default: `"jack"`)
- Journal entries created by Jack are attributed via these fields (requires adding `actor_type` and `actor_id` columns to `journal_entries`)

### Active Trip Resolution
- Tools that need a trip accept an optional `trip_id` parameter
- If `trip_id` is omitted, resolve to the single trip in `started` state
- If 0 or 2+ trips are started, return an error asking for explicit `trip_id`

### Idempotency for Telegram
- `create_journal_entry` and `create_comment` accept optional `telegram_message_id`
- If a record with the same `[trip_id, telegram_message_id]` exists, return it instead of creating a duplicate
- Requires adding `telegram_message_id` column to `journal_entries` and `comments`

---

## Files to Create (~8)

### Server
1. `app/mcp/trip_journal_server.rb` — MCP server instance with all tools
2. `app/mcp/tools/base_tool.rb` — base class with auth, trip resolution, actor helpers

### Tools (in `app/mcp/tools/`)
3. `app/mcp/tools/create_journal_entry.rb`
4. `app/mcp/tools/update_journal_entry.rb`
5. `app/mcp/tools/list_journal_entries.rb`
6. `app/mcp/tools/create_comment.rb`
7. `app/mcp/tools/add_reaction.rb`
8. `app/mcp/tools/update_trip.rb`
9. `app/mcp/tools/transition_trip.rb`
10. `app/mcp/tools/toggle_checklist_item.rb`
11. `app/mcp/tools/list_checklists.rb`
12. `app/mcp/tools/get_trip_status.rb`

### Controller
13. `app/controllers/mcp_controller.rb` — HTTP endpoint at `/mcp`, auth gate, delegates to MCP server

### Migrations
14. `db/migrate/xxx_add_actor_fields_to_journal_entries.rb` — `actor_type`, `actor_id` columns
15. `db/migrate/xxx_add_telegram_message_id_to_journal_entries.rb` — `telegram_message_id` column
16. `db/migrate/xxx_add_telegram_message_id_to_comments.rb` — `telegram_message_id` column

## Files to Modify (~4)

17. `Gemfile` — add `gem "mcp", "~> 0.8"`
18. `config/routes.rb` — add MCP route (`post "/mcp", to: "mcp#handle"`)
19. `app/models/journal_entry.rb` — add actor and telegram fields
20. `app/models/comment.rb` — add telegram_message_id field

---

## Key Design Decisions

1. **Class-based tools** — each tool is a class inheriting from `MCP::Tool` rather than using `define_tool` blocks. This keeps each tool testable and under 50 lines.

2. **Controller-based HTTP transport** — rather than using `StreamableHTTPTransport` directly (which manages its own sessions/streaming), use a simple Rails controller that calls `server.handle_json(request_body)` for stateless JSON-RPC. This avoids Rack-level complexity and integrates naturally with Rails middleware (logging, error handling).

3. **Shared secret auth, not Rodauth** — Jack is a system actor, not a user. Auth is a simple `MCP_API_KEY` env var checked in a `before_action`. No session, no cookies.

4. **Delegate to existing Actions** — tools call the same `JournalEntries::Create`, `Trips::Update`, etc. that controllers use. No business logic in MCP tools.

5. **Jack operator user** — Jack needs a User record to satisfy `belongs_to :author` on journal entries. Create a system user on first MCP request (or via seeds) with `actor_type: "system"` role.

## Risks

1. **MCP gem 0.8.0 API stability** — the gem is pre-1.0. The `Tool.define` and `Server#handle_json` APIs may change. Mitigate by pinning `~> 0.8` and wrapping in our own base class.

2. **Idempotency complexity** — `telegram_message_id` uniqueness scope must be `[trip_id, telegram_message_id]`, not just `telegram_message_id`, because different trips could have entries from the same Telegram message. Add a unique index.

3. **Active trip resolution ambiguity** — if multiple trips are in `started` state, Jack can't auto-resolve. Return a clear error listing the started trips so the AI can ask the user which one.

4. **Large response payloads** — `list_journal_entries` with rich text bodies could be large. Paginate with `limit` (default 10) and `offset` parameters. Strip HTML from bodies in list responses, return full body only in show.

---

## Verification

### Automated Tests
```bash
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
mise x -- bundle exec rake project:lint
```

### MCP-Specific Tests (`spec/mcp/`)
- Each tool has a spec verifying:
  - Correct delegation to the Action
  - Input schema validation (required params)
  - Success and error responses
  - Actor attribution on created records
  - Idempotency (telegram_message_id deduplication)
- Server spec verifying:
  - Tool registration (all 10 tools listed)
  - Auth rejection without API key
  - JSON-RPC protocol compliance

### Runtime Test Checklist
- [ ] `POST /mcp` with valid API key returns MCP initialize response
- [ ] `POST /mcp` without API key returns 401
- [ ] `tools/list` returns all 10 tools
- [ ] `tools/call create_journal_entry` creates an entry with actor_type "Jack"
- [ ] Duplicate `telegram_message_id` returns existing entry (idempotent)
- [ ] `tools/call get_trip_status` returns correct trip metadata
- [ ] `tools/call transition_trip` changes trip state
- [ ] `tools/call list_journal_entries` paginates correctly
- [ ] Active trip resolution works with exactly 1 started trip
- [ ] Active trip resolution errors with 0 or 2+ started trips
- [ ] All existing tests still pass
- [ ] No Bullet N+1 alerts

### Definition of Done
- [ ] All 10 MCP tools callable and return correct results
- [ ] Authentication enforced via MCP_API_KEY
- [ ] Idempotency works for journal entries and comments
- [ ] Active trip resolution works correctly
- [ ] Actor attribution recorded on Jack-created records
- [ ] Specs for every tool, server, and controller
- [ ] No regressions in existing test suite
- [ ] Runtime verification via curl to `/mcp` endpoint
