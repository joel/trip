# MCP API Curl Cheat-Sheet

The Trip Journal MCP server is a **stateless** JSON-RPC 2.0 endpoint. No session, no handshake, no special client required. Every request is independent -- you can call `tools/call` directly without calling `initialize` first.

## The One Rule

Every tool call uses the **same** JSON-RPC method: `tools/call`. The tool name goes in `params.name`, the tool arguments go in `params.arguments`.

```
Wrong:  {"method": "get_trip_status", "params": {}}             --> "Method not found"
Right:  {"method": "tools/call", "params": {"name": "get_trip_status", "arguments": {}}}
```

The only three JSON-RPC methods the server understands are:
- `initialize` -- returns server info and capabilities
- `tools/list` -- returns all 12 tool definitions
- `tools/call` -- invokes a tool

## Connection

```
Endpoint:     POST https://catalyst.workeverywhere.app/mcp
Content-Type: application/json
Auth:         Authorization: Bearer <MCP_API_KEY>
```

## Template

Every request follows this exact shape:

```bash
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": "1",
    "method": "tools/call",
    "params": {
      "name": "<TOOL_NAME>",
      "arguments": { <TOOL_ARGUMENTS> }
    }
  }'
```

The `id` field can be any string -- it's echoed back in the response so you can match request/response pairs.

## Response Format

Success:
```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "result": {
    "content": [{"type": "text", "text": "{\"trip_id\":\"...\",\"name\":\"...\"}"}],
    "isError": false
  }
}
```

Error:
```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "result": {
    "content": [{"type": "text", "text": "Trip not found: bad-uuid"}],
    "isError": true
  }
}
```

The `text` field contains JSON for success responses (parse it) or a plain error message for failures.

---

## Tools

### Get Trip Status

Find the active trip and its stats. No arguments needed if exactly one trip is in `started` state.

```bash
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": "1",
    "method": "tools/call",
    "params": {
      "name": "get_trip_status",
      "arguments": {}
    }
  }'
```

With explicit trip:
```json
"arguments": { "trip_id": "<uuid>" }
```

### List Journal Entries

```bash
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": "2",
    "method": "tools/call",
    "params": {
      "name": "list_journal_entries",
      "arguments": { "limit": 5, "offset": 0 }
    }
  }'
```

Optional: `trip_id`, `limit` (1-100, default 10), `offset` (default 0).

### Create Journal Entry

```bash
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": "3",
    "method": "tools/call",
    "params": {
      "name": "create_journal_entry",
      "arguments": {
        "name": "Day 1 - Arrival in Reykjavik",
        "entry_date": "2026-03-25",
        "body": "<p>Landed at Keflavik airport. The wind is fierce.</p>",
        "location_name": "Reykjavik, Iceland"
      }
    }
  }'
```

Required: `name`, `entry_date`. Optional: `trip_id`, `body` (HTML), `location_name`, `description`, `actor_type` (default "Jack"), `actor_id` (default "jack").

### Update Journal Entry

```bash
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": "4",
    "method": "tools/call",
    "params": {
      "name": "update_journal_entry",
      "arguments": {
        "journal_entry_id": "<uuid>",
        "body": "<p>Updated with more details about the northern lights.</p>"
      }
    }
  }'
```

Required: `journal_entry_id` + at least one of `name`, `body`, `entry_date`, `location_name`, `description`.

### Attach Images via URL

```bash
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": "5",
    "method": "tools/call",
    "params": {
      "name": "add_journal_images",
      "arguments": {
        "journal_entry_id": "<uuid>",
        "urls": [
          "https://cdn.example.com/photo1.jpg",
          "https://cdn.example.com/photo2.jpg"
        ]
      }
    }
  }'
```

Max 5 URLs per call, HTTPS only, 10MB per image, jpeg/png/webp/gif.

### Upload Images via Base64

```bash
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": "6",
    "method": "tools/call",
    "params": {
      "name": "upload_journal_images",
      "arguments": {
        "journal_entry_id": "<uuid>",
        "images": [
          { "data": "<base64-encoded-jpeg>", "filename": "sunset.jpg" },
          { "data": "<base64-encoded-png>" }
        ]
      }
    }
  }'
```

Max 5 images per call, 10MB each. `filename` is optional (auto-generated from MIME type). Content type detected from bytes, not declared.

### Create Comment

```bash
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": "7",
    "method": "tools/call",
    "params": {
      "name": "create_comment",
      "arguments": {
        "journal_entry_id": "<uuid>",
        "body": "What an incredible view!"
      }
    }
  }'
```

### Add Reaction

Toggle an emoji on a journal entry. Call again to remove.

```bash
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": "8",
    "method": "tools/call",
    "params": {
      "name": "add_reaction",
      "arguments": {
        "journal_entry_id": "<uuid>",
        "emoji": "fire"
      }
    }
  }'
```

Allowed emojis: `thumbsup`, `heart`, `tada`, `eyes`, `fire`, `rocket`.

### Update Trip

```bash
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": "9",
    "method": "tools/call",
    "params": {
      "name": "update_trip",
      "arguments": {
        "name": "Iceland Adventure 2026",
        "description": "10-day road trip around the ring road"
      }
    }
  }'
```

### Transition Trip State

```bash
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": "10",
    "method": "tools/call",
    "params": {
      "name": "transition_trip",
      "arguments": {
        "new_state": "started"
      }
    }
  }'
```

Valid states: `planning`, `started`, `finished`, `cancelled`, `archived`. Transitions must follow the state machine (e.g., can't go from `planning` directly to `finished`).

### List Checklists

```bash
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": "11",
    "method": "tools/call",
    "params": {
      "name": "list_checklists",
      "arguments": {}
    }
  }'
```

### Toggle Checklist Item

```bash
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": "12",
    "method": "tools/call",
    "params": {
      "name": "toggle_checklist_item",
      "arguments": {
        "checklist_item_id": "<uuid>"
      }
    }
  }'
```

---

## Trip Resolution

When `trip_id` is omitted, the server auto-resolves to the single trip in `started` state. If zero or multiple trips are started, you get an error asking for an explicit `trip_id`.

## State Guards

| Guard | Allowed states | Tools |
|-------|---------------|-------|
| writable | planning, started | create/update entry, add/upload images, update trip, toggle checklist |
| commentable | planning, started, finished | create comment, add reaction |

## Quick Test

Verify the connection works:

```bash
export MCP_API_KEY="your-key-here"

# List all tools (no auth needed for this to parse, but auth needed for 200)
curl -s https://catalyst.workeverywhere.app/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_API_KEY" \
  -d '{"jsonrpc":"2.0","id":"test","method":"tools/list"}' \
  | python3 -c "import json,sys; tools=json.load(sys.stdin)['result']['tools']; print(f'{len(tools)} tools:'); [print(f'  - {t[\"name\"]}') for t in tools]"
```

Expected output:
```
12 tools:
  - add_journal_images
  - add_reaction
  - create_comment
  - create_journal_entry
  - get_trip_status
  - list_checklists
  - list_journal_entries
  - toggle_checklist_item
  - transition_trip
  - update_journal_entry
  - update_trip
  - upload_journal_images
```
