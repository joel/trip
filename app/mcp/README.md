# MCP Server -- Trip Journal

The Model Context Protocol (MCP) server exposes trip journaling capabilities to AI clients (Claude, Cursor, etc.) via a JSON-RPC endpoint.

> Open [`docs/mcp-architecture.excalidraw`](../../docs/mcp-architecture.excalidraw) in [excalidraw.com](https://excalidraw.com) for the interactive diagram.

## Architecture

```
  MCP Client (Claude, Cursor, etc.)
       |
       | POST /mcp  (Bearer token, application/json)
       v
  McpController
       | authenticate_api_key!
       | validate_content_type! (415 if not JSON)
       | rescue JSON::ParserError (-32700)
       v
  TripJournalServer (MCP::Server)
       | routes JSON-RPC: initialize, tools/list, tools/call
       v
  Tools::BaseTool
       | resolve_trip, resolve_jack_user
       | require_writable!, require_commentable!
       | validate_actor_type!
       | success_response / error_response
       v
  12 MCP Tools  -->  Actions (Dry::Monads)  -->  ActiveRecord
```

## Endpoint

| | |
|---|---|
| **URL** | `POST /mcp` |
| **Auth** | `Authorization: Bearer <MCP_API_KEY>` |
| **Content-Type** | `application/json` (required, returns 415 otherwise) |
| **Protocol** | JSON-RPC 2.0 (MCP specification) |

## API Key Scope

The `MCP_API_KEY` grants **unrestricted read/write access to all domain data** through the 12 registered tools. All actions are attributed to the **Jack** system actor (`jack@system.local`). This is by design -- Jack is the AI travel assistant and needs full access to operate.

Set the key in `.env.development`:

```
MCP_API_KEY=your-secret-key
```

## Tools

### Journal Entries

| Tool | Description | Required Params |
|------|-------------|-----------------|
| `create_journal_entry` | Create a journal entry for a trip | `name`, `entry_date` |
| `update_journal_entry` | Update an existing journal entry | `journal_entry_id` + at least one field |
| `list_journal_entries` | List entries with pagination (limit 1-100) | (none) |

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
| `add_reaction` | Toggle an emoji reaction on an entry | `journal_entry_id`, `emoji` |

### Trip Management

| Tool | Description | Required Params |
|------|-------------|-----------------|
| `update_trip` | Update a trip's name or description | at least one of `name`, `description` |
| `transition_trip` | Transition a trip to a new state | `new_state` |
| `get_trip_status` | Get status, dates, counts for a trip | (none) |

### Checklists

| Tool | Description | Required Params |
|------|-------------|-----------------|
| `list_checklists` | List all checklists with sections/items | (none) |
| `toggle_checklist_item` | Toggle a checklist item's completion | `checklist_item_id` |

## Trip Resolution

When `trip_id` is omitted, tools automatically resolve to the single trip in `started` state. If zero or multiple trips are started, the tool returns an error asking for an explicit `trip_id`.

## Input Validation

| Constraint | Details |
|-----------|---------|
| **actor_type** | Must be `Jack` or `System` (enum) |
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
