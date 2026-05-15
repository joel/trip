# MCP Server -- Trip Journal

The Model Context Protocol (MCP) server exposes trip journaling capabilities to AI clients (Claude, Cursor, etc.) via a JSON-RPC endpoint.

> Open [`docs/mcp-architecture.excalidraw`](../../docs/mcp-architecture.excalidraw) in [excalidraw.com](https://excalidraw.com) for the interactive diagram.

## Architecture

```
  MCP Client (Claude, Cursor, etc.)
       |
       | POST /mcp  (Bearer token, application/json,
       |             X-Agent-Identifier: <slug>)
       v
  McpController
       | authenticate_api_key!              --> 401 if Bearer invalid
       | validate_content_type!             --> 415 if not JSON
       | rescue JSON::ParserError           --> -32700
       | resolve X-Agent-Identifier         --> -32001 if missing/unknown
       v
  TripJournalServer (MCP::Server)
       | routes JSON-RPC: initialize, tools/list, tools/call
       | instructions_for(agent) templates the persona
       v
  Tools::BaseTool
       | resolve_trip, resolve_agent_user(server_context)
       | require_writable!, require_commentable!
       | success_response / error_response
       v
  23 MCP Tools  -->  Actions (Dry::Monads)  -->  ActiveRecord
```

## Endpoint

| | |
|---|---|
| **URL** | `POST /mcp` |
| **Auth** | `Authorization: Bearer <MCP_API_KEY>` + `X-Agent-Identifier: <slug>` |
| **Content-Type** | `application/json` (required, returns 415 otherwise) |
| **Protocol** | JSON-RPC 2.0 (MCP specification) |

## Authentication and Agent Identity

Requests carry two identity layers:

- **`MCP_API_KEY`** (HTTP `Authorization: Bearer …`) — shared channel secret. Grants access to the endpoint. Missing/wrong → HTTP 401.
- **`X-Agent-Identifier`** — slug of a registered `Agent` record. Resolves to the agent's `@system.local` User, used as author/actor for all writes. Missing/unknown → JSON-RPC `-32001` (HTTP 200 so the client sees the message).

Each agent has a `Agent(slug, name, user)` record. Register via Rails console:

```ruby
user = User.find_or_create_by!(email: "maree@system.local") { |u|
  u.name = "Marée"; u.status = 2
}
Agent.create!(slug: "maree", name: "Marée", user: user)
```

Set the endpoint secret in `.env.development`:

```
MCP_API_KEY=your-secret-key
```

## Tools

### Journal Entries

| Tool | Description | Required Params |
|------|-------------|-----------------|
| `create_journal_entry` | Create a journal entry for a trip | `name`, `entry_date` |
| `update_journal_entry` | Update an existing journal entry | `journal_entry_id` + at least one field |
| `delete_journal_entry` | Delete an entry (writable trips only) | `journal_entry_id` |
| `list_journal_entries` | List entries with pagination (limit 1-100) | (none) |
| `get_journal_entry` | Get one entry: HTML body, counts, image URLs | `journal_entry_id` |

### Images

| Tool | Description | Required Params |
|------|-------------|-----------------|
| `add_journal_images` | Attach images via HTTPS URLs (max 5/call, 10MB each) | `journal_entry_id`, `urls` |
| `upload_journal_images` | Upload images via base64-encoded data (max 5/call, 10MB each) | `journal_entry_id`, `images` |

Allowed types: jpeg, png, webp, gif. Max 20 images per entry. `add_journal_images` downloads from HTTPS URLs with pinned DNS and SSRF protection; all-or-nothing if any URL fails. `upload_journal_images` accepts base64-encoded data inline with optional filenames; content type is detected from bytes via Marcel (caller-declared type is ignored). Both emit the same `journal_entry.images_added` event.

### Social

| Tool | Description | Required Params |
|------|-------------|-----------------|
| `create_comment` | Add a comment to a journal entry | `journal_entry_id`, `body` |
| `update_comment` | Edit a comment's body (writable trips only) | `comment_id`, `body` |
| `delete_comment` | Delete a comment (writable trips only) | `comment_id` |
| `list_comments` | List an entry's comments, paginated, with author email + name | `journal_entry_id` |
| `add_reaction` | Toggle an emoji reaction on an entry | `journal_entry_id`, `emoji` |
| `list_reactions` | List an entry's reactions with reacting user | `journal_entry_id` |

### Trip Management

| Tool | Description | Required Params |
|------|-------------|-----------------|
| `update_trip` | Update a trip's name or description | at least one of `name`, `description` |
| `transition_trip` | Transition a trip to a new state | `new_state` |
| `get_trip_status` | Get status, dates, counts for a trip | (none) |
| `list_trips` | List all trips (any state, incl. archived), paginated | (none) |

### Checklists

| Tool | Description | Required Params |
|------|-------------|-----------------|
| `list_checklists` | List all checklists with sections/items | (none) |
| `create_checklist` | Create a checklist on a trip (writable only) | `name` |
| `update_checklist` | Rename / reposition a checklist (writable only) | `checklist_id` + at least one field |
| `delete_checklist` | Delete a checklist + its sections/items (writable only) | `checklist_id` |
| `create_checklist_item` | Add an item to an existing section (writable only) | `checklist_section_id`, `content` |
| `toggle_checklist_item` | Toggle a checklist item's completion | `checklist_item_id` |

### Scope boundary (deliberately human-only)

The MCP surface is intentionally limited to **content curation**. The
following are **not** exposed and remain human-only operations:

- **Trip creation** — a human sets the context the agent works inside.
- **Member administration** — `assign`/`remove`/`list` trip members.
- **Invitations** — onboarding new people is a human concern.
- **Exports** — `Export#user` is a human recipient; needs an explicit
  permission decision.

Also out of scope until the underlying domain actions exist: image
removal/replacement, checklist-item update/delete, checklist-section
CRUD, and hard trip deletion.

## Trip Resolution

When `trip_id` is omitted, tools automatically resolve to the single trip in `started` state. If zero or multiple trips are started, the tool returns an error asking for an explicit `trip_id`.

## Input Validation

| Constraint | Details |
|-----------|---------|
| **emoji** | Must be one of: `thumbsup`, `heart`, `tada`, `eyes`, `fire`, `rocket` (enum) |
| **new_state** | Must be one of: `planning`, `started`, `finished`, `cancelled`, `archived` (enum) |
| **limit** | Clamped to 1-100 |
| **offset** | Clamped to >= 0 |
| **Empty updates** | `update_trip` and `update_journal_entry` reject calls with no updatable params |

## State Guards

Tools respect the trip state machine:

| Guard | States allowed | Tools using it |
|-------|---------------|----------------|
| `require_writable!` | planning, started | create/update journal entries, add/upload images, update trip, toggle checklist |
| `require_commentable!` | planning, started, finished | create comment, add reaction |

## Error Handling

| Level | Behavior |
|-------|----------|
| **Transport** | 415 for wrong Content-Type, JSON-RPC `-32700` for malformed JSON |
| **Auth** | 401 for missing/invalid Bearer token |
| **Tool** | `isError: true` in MCP response body with descriptive message |

## Files

```
app/mcp/
  trip_journal_server.rb    # Server builder (name, version, instructions, tools)
  tools/
    base_tool.rb            # Shared helpers, guards, trip resolution
    create_journal_entry.rb
    update_journal_entry.rb
    list_journal_entries.rb
    create_comment.rb
    add_reaction.rb
    update_trip.rb
    transition_trip.rb
    toggle_checklist_item.rb
    list_checklists.rb
    get_trip_status.rb
    add_journal_images.rb
    upload_journal_images.rb
    get_journal_entry.rb       # Phase 20
    delete_journal_entry.rb    # Phase 20
    update_comment.rb          # Phase 20
    delete_comment.rb          # Phase 20
    list_comments.rb           # Phase 20
    list_reactions.rb          # Phase 20
    list_trips.rb              # Phase 20
    create_checklist.rb        # Phase 20
    update_checklist.rb        # Phase 20
    delete_checklist.rb        # Phase 20
    create_checklist_item.rb   # Phase 20
```

## Testing

```bash
# Run MCP-specific tests
mise x -- bundle exec rspec spec/mcp/ spec/requests/mcp_spec.rb

# Integration test example (tools/call through HTTP)
# See spec/requests/mcp_spec.rb for the full test
```

## Claude Desktop Configuration

To connect Claude Desktop to this MCP server, add to your Claude config:

```json
{
  "mcpServers": {
    "trip-journal": {
      "url": "https://catalyst.workeverywhere.docker/mcp",
      "headers": {
        "Authorization": "Bearer your-mcp-api-key"
      }
    }
  }
}
```
