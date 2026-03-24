---
name: trip-journal-mcp
description: Connect to and operate the Trip Journal MCP server as Jack, the AI travel assistant. Use when the user asks to interact with trips, journal entries, images, comments, reactions, or checklists through the MCP endpoint -- or when configuring an MCP client (Claude Desktop, Cursor, etc.) to connect to this service. Covers all 11 tools, authentication, input validation, trip state constraints, and common workflows.
compatibility: Requires a running Trip Journal instance with MCP_API_KEY configured
metadata:
  author: joel
  version: "1.0"
---

# Trip Journal MCP Server

You are connecting to the Trip Journal MCP server as **Jack**, an AI travel assistant. Jack can create and manage journal entries, attach images via URLs, add comments and reactions, update trip details, transition trip states, toggle checklist items, and query trip status.

## Connection

| | |
|---|---|
| **Endpoint** | `POST /mcp` |
| **Auth** | `Authorization: Bearer <MCP_API_KEY>` |
| **Content-Type** | `application/json` (required -- returns 415 otherwise) |
| **Protocol** | JSON-RPC 2.0 ([MCP specification](https://modelcontextprotocol.io)) |

### Claude Desktop / Cursor Configuration

```json
{
  "mcpServers": {
    "trip-journal": {
      "url": "https://catalyst.workeverywhere.docker/mcp",
      "headers": {
        "Authorization": "Bearer <MCP_API_KEY>"
      }
    }
  }
}
```

### API Key Scope

The `MCP_API_KEY` grants **unrestricted read/write access to all domain data**. All actions are attributed to the Jack system actor (`jack@system.local`). This is by design -- Jack operates on behalf of the user across all trips.

## Tools Reference

### Journal Entries

| Tool | Description | Required | Optional |
|------|-------------|----------|----------|
| `create_journal_entry` | Create a journal entry | `name`, `entry_date` | `trip_id`, `body`, `location_name`, `description`, `actor_type`, `actor_id`, `telegram_message_id` |
| `update_journal_entry` | Update an existing entry | `journal_entry_id` + at least one field | `name`, `body`, `entry_date`, `location_name`, `description` |
| `list_journal_entries` | List entries with pagination | (none) | `trip_id`, `limit` (1-100, default 10), `offset` (>= 0) |

### Images

| Tool | Description | Required | Optional |
|------|-------------|----------|----------|
| `add_journal_images` | Attach images via HTTPS URLs | `journal_entry_id`, `urls` (array, max 5) | (none) |

Image constraints: HTTPS only, max 5 URLs per call, max 10 MB per image, max 20 images per entry. Allowed content types: `image/jpeg`, `image/png`, `image/webp`, `image/gif`. Downloads use pinned DNS resolution with SSRF protection (internal/private IPs blocked). The operation is all-or-nothing -- if any URL fails, no images are attached.

### Social

| Tool | Description | Required | Optional |
|------|-------------|----------|----------|
| `create_comment` | Add a comment to an entry | `journal_entry_id`, `body` | `telegram_message_id` |
| `add_reaction` | Toggle an emoji reaction | `journal_entry_id`, `emoji` | (none) |

### Trip Management

| Tool | Description | Required | Optional |
|------|-------------|----------|----------|
| `update_trip` | Update name or description | at least one of `name`, `description` | `trip_id` |
| `transition_trip` | Change trip state | `new_state` | `trip_id` |
| `get_trip_status` | Get status, dates, counts | (none) | `trip_id` |

### Checklists

| Tool | Description | Required | Optional |
|------|-------------|----------|----------|
| `list_checklists` | List all checklists with sections/items | (none) | `trip_id` |
| `toggle_checklist_item` | Toggle item completion | `checklist_item_id` | (none) |

## Trip Resolution

When `trip_id` is omitted, tools auto-resolve to the **single trip in `started` state**. If zero or multiple trips are started, the tool returns an error:

- `"No active trip found. Provide an explicit trip_id."`
- `"Multiple active trips: <ids>. Provide an explicit trip_id."`

Use `get_trip_status` without a `trip_id` to discover the active trip, or use `list_journal_entries` to browse.

## Input Constraints

| Field | Constraint |
|-------|-----------|
| `actor_type` | Enum: `Jack`, `System` |
| `emoji` | Enum: `thumbsup`, `heart`, `tada`, `eyes`, `fire`, `rocket` |
| `new_state` | Enum: `planning`, `started`, `finished`, `cancelled`, `archived` |
| `limit` | Clamped to 1-100 |
| `offset` | Clamped to >= 0 |

Empty updates are rejected -- `update_trip` and `update_journal_entry` require at least one field to change.

## Trip State Machine

```
planning --> started --> finished --> archived
    |            |
    +-> cancelled <-+
    ^            |
    +------------+
```

### Valid Transitions

| From | To |
|------|----|
| planning | started, cancelled |
| started | finished, cancelled |
| finished | archived |
| cancelled | planning |
| archived | (none -- terminal) |

### State Guards

Tools enforce state constraints. Calling a tool on an incompatible trip state returns an error.

| Guard | Allowed states | Tools |
|-------|---------------|-------|
| `writable` | planning, started | create/update journal entry, update trip, toggle checklist |
| `commentable` | planning, started, finished | create comment, add reaction |

## Idempotency

`create_journal_entry` and `create_comment` support idempotency via `telegram_message_id`. If a record with the same `telegram_message_id` already exists, the tool returns the existing record instead of creating a duplicate.

## Error Handling

| Level | Behavior |
|-------|----------|
| **Transport** | 415 for wrong Content-Type, JSON-RPC `-32700` for malformed JSON |
| **Auth** | 401 for missing/invalid Bearer token |
| **Tool** | `isError: true` in MCP response with descriptive message |

Error messages are actionable:
- `"Trip not found: <uuid>"` -- invalid trip_id
- `"Trip '<name>' is not writable (state: finished)"` -- state guard violation
- `"No updatable parameters provided"` -- empty update rejected
- `"Invalid actor_type \"hacker\". Must be one of: Jack, System"` -- enum violation

## Common Workflows

### Start a new trip and journal the first day

```
1. get_trip_status                           # Find active trip
2. transition_trip(new_state: "started")     # Start it (if in planning)
3. create_journal_entry(
     name: "Day 1 - Arrival",
     entry_date: "2026-03-24",
     body: "<p>We arrived in...</p>",
     location_name: "Tokyo, Japan"
   )
4. add_reaction(journal_entry_id: "<id>", emoji: "fire")
```

### Attach photos to a journal entry

```
1. list_journal_entries(limit: 1)            # Find the latest entry
2. add_journal_images(
     journal_entry_id: "<id>",
     urls: [
       "https://cdn.example.com/photo1.jpg",
       "https://cdn.example.com/photo2.jpg"
     ]
   )
```

### Add commentary to an existing entry

```
1. list_journal_entries(limit: 5)            # Find recent entries
2. create_comment(
     journal_entry_id: "<id>",
     body: "What a beautiful sunset!"
   )
3. add_reaction(journal_entry_id: "<id>", emoji: "heart")
```

### Review checklists before a trip

```
1. list_checklists                           # See all checklists
2. toggle_checklist_item(checklist_item_id: "<id>")  # Mark items done
```

### Wrap up a trip

```
1. transition_trip(new_state: "finished")    # End the trip
2. transition_trip(trip_id: "<id>", new_state: "archived")  # Archive it
```

## Domain Model

```
Trip (state machine: planning/started/finished/cancelled/archived)
  |-- has_many :journal_entries
  |     |-- has_rich_text :body (HTML)
  |     |-- has_many_attached :images (Active Storage)
  |     |-- has_many :comments
  |     |-- has_many :reactions (polymorphic)
  |
  |-- has_many :checklists
  |     |-- has_many :checklist_sections
  |           |-- has_many :checklist_items
  |
  |-- has_many :reactions (polymorphic)
```
