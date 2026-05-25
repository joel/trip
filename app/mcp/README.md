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
  25 MCP Tools  -->  Actions (Dry::Monads)  -->  ActiveRecord
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

### Images and Videos

**Recommended flow: Direct Upload.** Bytes flow agent → SeaweedFS over the public HTTPS endpoint; Rails is only on the metadata path. No 50 MB base64 inflation, no server-side buffering, no SSRF download — and it's the only path that handles GB-scale videos.

| Tool | Description | Required Params |
|------|-------------|-----------------|
| `prepare_journal_image_upload` | **Step 1 (images, recommended)** — returns `{signed_id, put_url, headers, expires_at}` for a presigned PUT to SeaweedFS. Max 50 MB; jpeg/png/webp/gif. | `journal_entry_id`, `filename`, `content_type`, `byte_size`, `checksum` |
| `prepare_journal_video_upload` | **Step 1 (videos, recommended)** — same shape. Max 1 GB; mp4/quicktime/webm. | `journal_entry_id`, `filename`, `content_type`, `byte_size`, `checksum` |
| `add_journal_images` | **Step 3 (images)** — attach via `signed_ids` (preferred) **or** HTTPS `urls` (SSRF-hardened fallback, 10 MB cap). Max 5/call; 20 per entry. | `journal_entry_id` + exactly one of `signed_ids` / `urls` |
| `add_journal_videos` | **Step 3 (videos)** — attach via `signed_ids` (preferred) **or** HTTPS `urls` (200 MB cap fallback). Max 5/call; 5 per entry. | `journal_entry_id` + exactly one of `signed_ids` / `urls` |
| `upload_journal_images` | Fallback: base64 inline (max 5/call, 10 MB each). Use only when HTTP PUT isn't available. | `journal_entry_id`, `images` |
| `upload_journal_videos` | Fallback: base64 inline for short clips (max 2/call, 50 MB each). | `journal_entry_id`, `videos` |

**Direct Upload flow** (preferred for AI agents):

```bash
# 1. Prepare: server creates the blob row + presigned PUT URL.
POST /mcp  tools/call  prepare_journal_video_upload \
    {journal_entry_id, filename, content_type, byte_size, checksum}
# → { signed_id, put_url, headers: {...}, expires_at }

# 2. PUT the bytes directly to SeaweedFS — no Rails on this hop.
curl -X PUT "<put_url>" \
     -H "Content-Type: video/mp4" \
     -H "Content-MD5: <checksum>" \
     --data-binary @clip.mp4

# 3. Attach: server validates the blob's metadata + writability,
#    then attaches and emits journal_entry.videos_added.
POST /mcp  tools/call  add_journal_videos \
    {journal_entry_id, signed_ids: ["<signed_id>"]}
```

`checksum` is the base64-encoded MD5 of the bytes; the SDK signs Content-MD5 into the PUT URL, so the bytes you PUT must match. `signed_id` and `put_url` are valid for 10 minutes; if the agent doesn't follow up with `add_journal_videos`, `OrphanBlobsCleanupJob` purges the unattached blob ~1 hour later.

Allowed image types: jpeg, png, webp, gif. Max 20 images per entry. `add_journal_images` with `urls` downloads with pinned DNS and SSRF protection; all-or-nothing if any URL fails. `upload_journal_images` accepts base64 inline; content type is detected from bytes via Marcel. All paths emit the same `journal_entry.images_added` event.

Video: types mp4, quicktime (.mov), webm; max 5 videos per entry; format/size/duration validated. The `urls` fallback reuses the pinned-DNS/SSRF download streamed to disk. All paths emit `journal_entry.videos_added`, which triggers async transcoding (`ProcessJournalVideosJob`) to a ≤720p web rendition + poster — the video is `pending` until then.

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
