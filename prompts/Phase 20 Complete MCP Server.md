# PRP: Phase 20 — Complete MCP Server (Trip Administration Tools)

**Status:** Draft (awaiting approval — do **not** start coding)
**Date:** 2026-05-14
**Type:** Feature (additive — new MCP tools only)
**Confidence Score:** 9/10

One-pass implementation confidence is high: every new tool wraps an existing `app/actions/**` operation with the same pattern as the 12 tools shipped in Phases 9–19. No new database table, no new auth surface, no new gem, no controller change. After trimming trip creation, member administration, and invitations, Phase 20 is a focused, mechanical addition of 11 tools.

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Goals and Non-Goals](#2-goals-and-non-goals)
3. [Gap Analysis (Existing vs Missing)](#3-gap-analysis-existing-vs-missing)
4. [Design Decisions To Confirm](#4-design-decisions-to-confirm)
5. [Codebase Context](#5-codebase-context)
6. [Tool Inventory (Phase 20)](#6-tool-inventory-phase-20)
7. [Implementation Blueprint](#7-implementation-blueprint)
8. [Task List (ordered)](#8-task-list-ordered)
9. [Testing Strategy](#9-testing-strategy)
10. [Validation Gates (Executable)](#10-validation-gates-executable)
11. [Runtime Test Checklist](#11-runtime-test-checklist)
12. [Documentation Updates](#12-documentation-updates)
13. [Rollback Plan](#13-rollback-plan)
14. [Future Work (Out of Scope)](#14-future-work-out-of-scope)
15. [Reference Documentation](#15-reference-documentation)
16. [Skill Self-Evaluation](#16-skill-self-evaluation)
17. [Open Questions for the Operator](#17-open-questions-for-the-operator)

---

## 1. Problem Statement

The MCP server (`app/mcp/trip_journal_server.rb`) currently exposes **12 tools**. A registered agent (Jack, Marée, …) can create journal entries, attach images, comment, react, update a trip, transition trip state, toggle checklist items, and read entries/checklists/status. Several content-curation operations that contributors can perform through the web UI are unreachable from the MCP surface.

Concretely, an agent today **cannot**:

- Delete a journal entry it created by mistake.
- Edit or delete a comment.
- Read a single journal entry's full body, or list its comments / reactions.
- List the trips it should know about.
- Create, rename, or delete a checklist.
- Add a new item to an existing checklist section.

The domain layer (`app/actions/**`) already implements 7 of these 11 missing operations. Phase 20 wraps them in `Tools::*` classes and registers them. The 4 read-only tools have no underlying action — they are thin Active Record reads, mirroring the shape of `list_journal_entries` / `get_trip_status`.

Operations that touch **people** (creating trips, assigning/removing trip members, sending invitations) are intentionally **left to human operators**. Likewise `request_export` is deferred. See §14 for the rationale.

---

## 2. Goals and Non-Goals

### Goals

1. Bring the MCP tool count from 12 → 23 by adding 11 new tools.
2. Every new tool follows the existing `Tools::*` pattern: `BaseTool` subclass, `description`, `input_schema`, `self.call(..., server_context: {})`, `success_response` / `error_response`, `require_writable!` / `require_commentable!` guards where appropriate, `rescue ToolError` + `rescue ActiveRecord::RecordNotFound`.
3. Every write tool that attributes a database write uses `resolve_agent_user(server_context)` — never hardcodes a user, never trusts a `user_id` parameter from the client.
4. Every new tool has a spec file in `spec/mcp/tools/` mirroring the spec shape of the closest existing tool (happy path + not-found + state-guard + validation-failure where applicable).
5. `app/mcp/README.md`, `docs/mcp-curl-cheatsheet.md`, `AGENTS.md`, `prompts/PROJECT SUMMARY.md`, and `.claude/skills/trip-journal-mcp/SKILL.md` reflect the new tool count and capabilities.
6. `tools/list` returns 23 tools with valid input schemas; `bundle exec rake project:tests` and `project:system-tests` both pass.

### Non-Goals (explicit — defer to future phases)

- **Trip creation (`create_trip`).** Creating a trip is the human operator's responsibility — it sets the context the agent then works inside.
- **Member administration (`assign_trip_member`, `remove_trip_member`, `list_trip_members`).** Adding/removing humans on a trip is a human concern; an agent should not be deciding who has access.
- **Invitations (`send_invitation`).** Inviting a new person to the platform is member administration's entry point and stays with humans for consistency.
- **`request_export`.** Deferred — `Export#user_id` semantics tie exports to a human recipient, and the permission model needs an operator decision.
- **Image removal / replacement.** No `JournalEntries::DetachImage` action exists. Out of scope until that ships.
- **Checklist item update / delete.** No `ChecklistItems::Update` / `Delete` actions exist. Toggling stays the only mutation.
- **Checklist section CRUD.** No `app/actions/checklist_sections/` folder. `create_checklist_item` requires an existing `checklist_section_id`; section management is out of scope.
- **Trip deletion.** No `Trips::Delete` action. Trips are deactivated via state transition (`archived` / `cancelled`).
- **`accept_invitation`.** Recipient's flow, not an agent's.
- **Access requests (`submit`, `approve`, `reject`).** Admin / public flows; not appropriate for an agent endpoint.
- **Subscribe / unsubscribe a journal entry's notifications.** System actors are explicitly filtered out of subscription; having an agent subscribe itself would re-introduce the auto-notify-yourself bug Phase 15 QA flagged.
- **ActionPolicy enforcement in tools.** Existing 12 tools intentionally bypass policy (channel auth + agent slug is the authorization surface for MCP). New tools mirror that. **Do not** add `authorize!` calls.
- **Phase-2 per-trip pairing keys.** Phase 19 explicitly deferred those.

---

## 3. Gap Analysis (Existing vs Missing)

Cross-reference between `app/actions/**` and `TripJournalServer::TOOLS` (current state, 2026-05-14):

### Trips

| Domain action | MCP tool? | Phase-20 action |
|---|---|---|
| `Trips::Create` | ❌ | **DEFERRED** (human-only — see §2) |
| `Trips::Update` | ✅ `update_trip` | — |
| `Trips::TransitionState` | ✅ `transition_trip` | — |
| (no list reader) | ❌ | **ADD** `list_trips` |

### Journal Entries

| Domain action | MCP tool? | Phase-20 action |
|---|---|---|
| `JournalEntries::Create` | ✅ | — |
| `JournalEntries::Update` | ✅ | — |
| `JournalEntries::Delete` | ❌ | **ADD** `delete_journal_entry` |
| `JournalEntries::AttachImages` | ✅ `add_journal_images` | — |
| `JournalEntries::UploadImages` | ✅ `upload_journal_images` | — |
| (no single-entry reader) | ❌ | **ADD** `get_journal_entry` |

### Comments

| Domain action | MCP tool? | Phase-20 action |
|---|---|---|
| `Comments::Create` | ✅ | — |
| `Comments::Update` | ❌ | **ADD** `update_comment` |
| `Comments::Delete` | ❌ | **ADD** `delete_comment` |
| (no list reader) | ❌ | **ADD** `list_comments` |

### Reactions

| Domain action | MCP tool? | Phase-20 action |
|---|---|---|
| `Reactions::Toggle` | ✅ `add_reaction` | — |
| (no list reader) | ❌ | **ADD** `list_reactions` |

### Trip Memberships

| Domain action | MCP tool? | Phase-20 action |
|---|---|---|
| `TripMemberships::Assign` | ❌ | **DEFERRED** (human-only — see §2) |
| `TripMemberships::Remove` | ❌ | **DEFERRED** (human-only) |
| (no list reader) | ❌ | **DEFERRED** (human-only) |

### Checklists

| Domain action | MCP tool? | Phase-20 action |
|---|---|---|
| `Checklists::Create` | ❌ | **ADD** `create_checklist` |
| `Checklists::Update` | ❌ | **ADD** `update_checklist` |
| `Checklists::Delete` | ❌ | **ADD** `delete_checklist` |
| `list_checklists` | ✅ | — |

### Checklist Items

| Domain action | MCP tool? | Phase-20 action |
|---|---|---|
| `ChecklistItems::Create` | ❌ | **ADD** `create_checklist_item` |
| `ChecklistItems::Toggle` | ✅ `toggle_checklist_item` | — |

### Invitations

| Domain action | MCP tool? | Phase-20 action |
|---|---|---|
| `Invitations::SendInvitation` | ❌ | **DEFERRED** (human-only — see §2) |
| `Invitations::Accept` | ❌ | **OUT** (recipient flow) |

### Deferred (have actions but kept out — see §2)

| Domain action | Reason for deferral |
|---|---|
| `Trips::Create` | Human operator sets the context the agent works in |
| `TripMemberships::Assign / Remove` | People-management is a human concern |
| `Invitations::SendInvitation` | Member administration's entry point — stays with humans |
| `Exports::RequestExport` | `Export#user_id` semantics; needs operator decision |
| `AccessRequests::Submit/Approve/Reject` | Admin flow; not an agent capability |

### Deferred (no action exists yet — need new domain code first)

- Remove / replace journal image
- Update / delete checklist item
- Checklist section CRUD
- Trip delete

---

## 4. Design Decisions To Confirm

These need the operator's sign-off **before** Step 1. Listed with my recommended default; if you accept the defaults the plan executes as-is.

| # | Decision | Recommended | Rationale |
|---|----------|-------------|-----------|
| 1 | Tool count target | **11 new tools (23 total)** | Maps 1:1 onto §3 gap table after the human-only carve-out. |
| 2 | Naming convention | Verb-object: `delete_journal_entry`, `update_comment`, etc. | Matches existing `create_journal_entry`, `update_trip`, `toggle_checklist_item`. |
| 3 | State guards on writes | `delete_journal_entry`, `update_comment`, `delete_comment`, `create_checklist`, `update_checklist`, `delete_checklist`, `create_checklist_item` → **`require_writable!`** (planning/started only). | Matches existing pattern: archived/finished trips are read-only. |
| 4 | Read tools — state guard | **None.** All states are listable. | Mirrors `list_journal_entries`, `list_checklists`. |
| 5 | Pagination on list tools | All new `list_*` tools accept `limit` (1–100, default 10) + `offset` (≥0, default 0); return `{ items: [...], total:, limit:, offset: }`. `list_reactions` returns without pagination (bounded by `Reaction::ALLOWED_EMOJIS.size × member_count`). | Mirrors `list_journal_entries`. |
| 6 | Authorization (policy enforcement) | **None.** Tools trust channel auth + agent identity. | Phase 19 established this; AGENTS.md MCP section codifies it. |
| 7 | `delete_*` idempotency | If the record is already gone (`ActiveRecord::RecordNotFound`), return a friendly error rather than a success. | Matches existing behaviour for `update_journal_entry`. |
| 8 | Commit grouping | **11 commits, one per tool** (+ 2 wrap-up commits for server instructions and docs). Each tool commit adds the tool file, its spec, registers it in `TOOLS`, and bumps the tool-count assertion in `trip_journal_server_spec.rb`. Reverting any single commit cleanly removes one tool with no broken test state. | Per operator preference for fine-grained revertability. |
| 9 | Single PR or multiple? | **One PR.** All 11 tools are mechanically the same pattern. | Matches the way Phases 9–11 batched related MCP work. |

**If any of the above are wrong, flag them in §17 Open Questions before approval.**

---

## 5. Codebase Context

### Files to **read** (no edits — pattern reference)

| File | What it shows |
|------|---------------|
| `app/mcp/tools/base_tool.rb` | Shared helpers: `success_response`, `error_response`, `resolve_trip`, `resolve_agent_user`, `require_writable!`, `require_commentable!`. **Do not modify in Phase 20.** |
| `app/mcp/tools/update_trip.rb` | Canonical "update with optional fields" tool — copy for `update_comment`, `update_checklist`. |
| `app/mcp/tools/toggle_checklist_item.rb` | Canonical "act on a single record by id" tool — copy for `delete_journal_entry`, `delete_comment`, `delete_checklist`. |
| `app/mcp/tools/list_journal_entries.rb` | Canonical paginated read — copy for `list_trips`, `list_comments`. |
| `app/mcp/tools/get_trip_status.rb` | Canonical single-record read — copy for `get_journal_entry`. |
| `app/mcp/tools/create_journal_entry.rb` | Canonical write tool using `resolve_agent_user` — reference for `create_checklist`, `create_checklist_item`. |
| `app/actions/CLAUDE.md` | Actions + Dry::Monads pattern; event names; pattern-matching. |
| `spec/mcp/tools/create_comment_spec.rb` | Spec shape: `let(:agent) { create(:agent) }`, `let(:context) { { agent: agent } }`, then `described_class.call(..., server_context: context)`. |
| `spec/mcp/tools/toggle_checklist_item_spec.rb` | Spec shape for state-guard + not-found assertions. |
| `spec/factories/agents.rb`, `spec/factories/users.rb` (`:system_actor` trait) | Factories Phase 20 specs depend on. |

### Files to **modify**

| File | Why |
|------|-----|
| `app/mcp/trip_journal_server.rb` | Append 11 new tools to the `TOOLS` array. Update `instructions_for` to mention the new capabilities (deletion, comment edit/delete, checklist management). |
| `app/mcp/tools/<new_tool>.rb` (×11) | New tool classes. |
| `spec/mcp/tools/<new_tool>_spec.rb` (×11) | New tool specs. |
| `spec/mcp/trip_journal_server_spec.rb` | Tool-count assertion 12 → 23. |
| `app/mcp/README.md` | New rows in every domain section; update "12 Tools" prose. |
| `docs/mcp-curl-cheatsheet.md` | New curl examples grouped by domain. |
| `AGENTS.md` | The "12 registered MCP tools" line → 23. |
| `prompts/PROJECT SUMMARY.md` | Line 31: "12 tools" → 23. |
| `.claude/skills/trip-journal-mcp/SKILL.md` | Inventory section sync. |

### Files to **create**

11 new tool files + 11 new spec files (see §6 inventory).

### Critical Gotchas

1. **UUID primary keys.** All record IDs the tools receive are UUIDs as strings. Pass them straight to `Model.find`.

2. **Don't `resolve_trip` for trip-derived operations.** Tools that operate on records that **already carry a trip** (a comment's journal entry's trip, a checklist's trip) derive the trip from the record, not from `trip_id`. Otherwise an agent could operate on Trip A's records while the "started trip" is Trip B and the writable check would target the wrong trip.

   Correct (from `toggle_checklist_item.rb`):
   ```ruby
   item = ChecklistItem.find(checklist_item_id)
   require_writable!(item.checklist_section.checklist.trip)
   ```

3. **`server_context` parameter naming.** Tools that **use** agent identity name the kwarg `server_context:` (un-underscored). Tools that don't use it name it `_server_context:`. In Phase 20, only `create_checklist`, `create_checklist_item` need un-underscored — they create records with attribution. The delete and update tools don't need the agent (the action signature doesn't take a user); use `_server_context:`. Same for all reads.

4. **State guards apply *after* lookup, before mutation:**
   ```ruby
   record = Model.find(id)                # 1. lookup (may raise RecordNotFound)
   require_writable!(record.trip)          # 2. guard (may raise ToolError)
   result = Action.new.call(...)           # 3. mutate
   ```

5. **Rescue order:**
   ```ruby
   rescue ToolError => e
     error_response(e.message)
   rescue ActiveRecord::RecordNotFound
     error_response("X not found: #{id}")
   ```

6. **Action signatures vary** — read each before writing the tool:
   - `Comments::Update.new.call(comment:, params:)`
   - `Comments::Delete.new.call(comment:)`
   - `Checklists::Create.new.call(params:, trip:)`
   - `Checklists::Update.new.call(checklist:, params:)`
   - `Checklists::Delete.new.call(checklist:)`
   - `ChecklistItems::Create.new.call(params:, checklist_section:)`
   - `JournalEntries::Delete.new.call(journal_entry:)`

7. **`Comments::Update`'s `params` whitelist is implicit.** `comment.update!(params)`, so the tool must filter — only `body` is sensibly updatable. Build `params = { body: body }.compact` and short-circuit if empty.

8. **Tool count assertion in `spec/mcp/trip_journal_server_spec.rb`.** Currently likely `eq(12)` — bump to 23. Verify exact wording before editing.

9. **MCP gem schema validation.** Use `enum: [...]` for constrained string fields; always provide `required:` even when empty.

10. **Overcommit + schema hook.** No migrations in Phase 20, so `RailsSchemaUpToDate` is non-issue. RuboCop, whitespace, capitalised subjects apply normally.

11. **Event subscriber check.** Phase 20 emits new events (`journal_entry.deleted`, `comment.updated`, `comment.deleted`, `checklist.created/updated/deleted`, `checklist_item.created`). Before merging, grep `config/initializers/event_subscribers.rb` + `app/subscribers/**` to confirm no subscriber emails the agent's own `@system.local` user when the actor is a system user. If any leaks, add a filter — see §17 Q3.

---

## 6. Tool Inventory (Phase 20)

### Read-only tools (no agent attribution needed — `_server_context:`)

| Tool | Input (required → optional) | Returns | Source |
|------|------------------------------|---------|--------|
| `get_journal_entry` | `journal_entry_id` | `{ id, name, body, entry_date, location_name, description, trip_id, comments_count, reactions_count, image_urls: [] }` | `JournalEntry.find` + assoc counts |
| `list_trips` | — → `limit`, `offset` | `{ trips: [{ id, name, state, start_date, end_date, member_count, entry_count }], total, limit, offset }` paginated | `Trip.all.order(...)` |
| `list_comments` | `journal_entry_id` → `limit`, `offset` | `{ comments: [{ id, body, author_email, author_name, created_at }], total, limit, offset }` | `entry.comments.chronological` |
| `list_reactions` | `journal_entry_id` | `{ reactions: [{ id, emoji, user_email, user_name }], total }` (no pagination) | `entry.reactions.includes(:user)` |

### Write tools

| Tool | Input (required → optional) | Returns | Domain action | `server_context` |
|------|------------------------------|---------|----------------|-------------------|
| `delete_journal_entry` | `journal_entry_id` | `{ deleted: true, id }` | `JournalEntries::Delete` (with `require_writable!`) | `_server_context:` (no attribution) |
| `update_comment` | `comment_id`, `body` | `{ id, body, journal_entry_id }` | `Comments::Update` (`require_writable!` on entry's trip) | `_server_context:` |
| `delete_comment` | `comment_id` | `{ deleted: true, id }` | `Comments::Delete` (`require_writable!`) | `_server_context:` |
| `create_checklist` | `name` → `trip_id`, `position` | `{ id, name, trip_id, position }` | `Checklists::Create` (`require_writable!`) | `_server_context:` (action doesn't take a user) |
| `update_checklist` | `checklist_id`, `name` → `position` | `{ id, name, position }` | `Checklists::Update` (`require_writable!`) | `_server_context:` |
| `delete_checklist` | `checklist_id` | `{ deleted: true, id }` | `Checklists::Delete` (`require_writable!`) | `_server_context:` |
| `create_checklist_item` | `checklist_section_id`, `content` → `position` | `{ id, content, completed, checklist_section_id }` | `ChecklistItems::Create` (`require_writable!`) | `_server_context:` |

**Total: 4 read tools + 7 write tools = 11 new tools.**

Note: with the trim, *none* of the new Phase-20 write tools need `resolve_agent_user`. The domain actions for delete/update/create-checklist/create-checklist-item don't take a user kwarg — events are attributed by record ownership, not by an actor argument. This simplifies the implementation considerably.

---

## 7. Implementation Blueprint

One representative tool per category is shown end-to-end. The remaining tools follow the same scaffolding — see §5 reference files.

### 7.1 Read tool — `get_journal_entry.rb`

```ruby
# frozen_string_literal: true

module Tools
  class GetJournalEntry < BaseTool
    description "Get a single journal entry by ID with full body, " \
                "image URLs, and counts"

    input_schema(
      properties: {
        journal_entry_id: {
          type: "string", description: "Journal entry UUID"
        }
      },
      required: %w[journal_entry_id]
    )

    def self.call(journal_entry_id:, _server_context: {})
      entry = JournalEntry.find(journal_entry_id)

      success_response(
        id: entry.id, name: entry.name,
        body: entry.body.to_s,
        entry_date: entry.entry_date.to_s,
        location_name: entry.location_name,
        description: entry.description,
        trip_id: entry.trip_id,
        comments_count: entry.comments.count,
        reactions_count: entry.reactions.count,
        image_urls: entry.images.map do |img|
          Rails.application.routes.url_helpers
               .rails_blob_url(img, host: ENV.fetch("APP_HOST", "localhost"))
        end
      )
    rescue ActiveRecord::RecordNotFound
      error_response("Journal entry not found: #{journal_entry_id}")
    end
  end
end
```

**Notes:**
- `body.to_s` returns the Action Text HTML (including embedded image references and formatting). Formatting matters to the operator, so HTML is preferred over `to_plain_text`.
- Image URLs need a host. Read from `ENV["APP_HOST"]`.

### 7.2 Paginated read tool — `list_comments.rb`

```ruby
# frozen_string_literal: true

module Tools
  class ListComments < BaseTool
    description "List comments on a journal entry with pagination"

    input_schema(
      properties: {
        journal_entry_id: { type: "string", description: "Journal entry UUID" },
        limit:  { type: "integer", description: "Max comments (default 10, max 100)" },
        offset: { type: "integer", description: "Skip count (default 0)" }
      },
      required: %w[journal_entry_id]
    )

    def self.call(journal_entry_id:, limit: 10, offset: 0, _server_context: {})
      entry = JournalEntry.find(journal_entry_id)
      limit = limit.to_i.clamp(1, 100)
      offset = [offset.to_i, 0].max

      scope = entry.comments.chronological.includes(:user)

      success_response(
        comments: scope.offset(offset).limit(limit).map { |c|
          {
            id: c.id, body: c.body,
            author_email: c.user.email,
            author_name: c.user.name,
            created_at: c.created_at.iso8601
          }
        },
        total: entry.comments.count, limit: limit, offset: offset
      )
    rescue ActiveRecord::RecordNotFound
      error_response("Journal entry not found: #{journal_entry_id}")
    end
  end
end
```

### 7.3 Single-record write — `delete_journal_entry.rb`

```ruby
# frozen_string_literal: true

module Tools
  class DeleteJournalEntry < BaseTool
    description "Delete a journal entry (only on writable trips)"

    input_schema(
      properties: {
        journal_entry_id: { type: "string", description: "Journal entry UUID" }
      },
      required: %w[journal_entry_id]
    )

    def self.call(journal_entry_id:, _server_context: {})
      entry = JournalEntry.find(journal_entry_id)
      require_writable!(entry.trip)

      result = JournalEntries::Delete.new.call(journal_entry: entry)

      case result
      in Dry::Monads::Success()
        success_response(deleted: true, id: journal_entry_id)
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ToolError => e
      error_response(e.message)
    rescue ActiveRecord::RecordNotFound
      error_response("Journal entry not found: #{journal_entry_id}")
    end
  end
end
```

### 7.4 Update-with-fields — `update_comment.rb`

```ruby
# frozen_string_literal: true

module Tools
  class UpdateComment < BaseTool
    description "Edit a comment's body (only on writable trips)"

    input_schema(
      properties: {
        comment_id: { type: "string", description: "Comment UUID" },
        body:       { type: "string", description: "New comment text" }
      },
      required: %w[comment_id body]
    )

    def self.call(comment_id:, body:, _server_context: {})
      comment = Comment.find(comment_id)
      require_writable!(comment.journal_entry.trip)

      params = { body: body }.compact
      raise ToolError, "No updatable parameters provided" if params.empty?

      result = Comments::Update.new.call(comment: comment, params: params)

      case result
      in Dry::Monads::Success(updated)
        success_response(
          id: updated.id, body: updated.body,
          journal_entry_id: updated.journal_entry_id
        )
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ToolError => e
      error_response(e.message)
    rescue ActiveRecord::RecordNotFound
      error_response("Comment not found: #{comment_id}")
    end
  end
end
```

### 7.5 Trip-scoped create — `create_checklist.rb`

```ruby
# frozen_string_literal: true

module Tools
  class CreateChecklist < BaseTool
    description "Create a new checklist on a trip"

    input_schema(
      properties: {
        trip_id:  { type: "string",
                    description: "Trip UUID (optional if exactly one trip is started)" },
        name:     { type: "string", description: "Checklist name" },
        position: { type: "integer", description: "Sort position (optional)" }
      },
      required: %w[name]
    )

    def self.call(name:, trip_id: nil, position: nil, _server_context: {})
      trip = resolve_trip(trip_id)
      require_writable!(trip)

      params = { name: name, position: position }.compact
      result = Checklists::Create.new.call(params: params, trip: trip)

      case result
      in Dry::Monads::Success(checklist)
        success_response(
          id: checklist.id, name: checklist.name,
          trip_id: checklist.trip_id, position: checklist.position
        )
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ToolError => e
      error_response(e.message)
    end
  end
end
```

### 7.6 Section-scoped create — `create_checklist_item.rb`

```ruby
# frozen_string_literal: true

module Tools
  class CreateChecklistItem < BaseTool
    description "Add a new item to an existing checklist section"

    input_schema(
      properties: {
        checklist_section_id: { type: "string", description: "Checklist section UUID" },
        content:              { type: "string", description: "Item text" },
        position:             { type: "integer", description: "Sort position (optional)" }
      },
      required: %w[checklist_section_id content]
    )

    def self.call(checklist_section_id:, content:, position: nil, _server_context: {})
      section = ChecklistSection.find(checklist_section_id)
      require_writable!(section.checklist.trip)

      params = { content: content, position: position }.compact
      result = ChecklistItems::Create.new.call(
        params: params, checklist_section: section
      )

      case result
      in Dry::Monads::Success(item)
        success_response(
          id: item.id, content: item.content,
          completed: item.completed, checklist_section_id: section.id
        )
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ToolError => e
      error_response(e.message)
    rescue ActiveRecord::RecordNotFound
      error_response("Checklist section not found: #{checklist_section_id}")
    end
  end
end
```

### 7.7 Registration

```ruby
# app/mcp/trip_journal_server.rb (end state — TOOLS array)
TOOLS = [
  # Existing 12
  Tools::CreateJournalEntry, Tools::UpdateJournalEntry,
  Tools::ListJournalEntries, Tools::CreateComment,
  Tools::AddReaction, Tools::UpdateTrip, Tools::TransitionTrip,
  Tools::ToggleChecklistItem, Tools::ListChecklists,
  Tools::GetTripStatus, Tools::AddJournalImages,
  Tools::UploadJournalImages,
  # Phase 20 — Reads
  Tools::GetJournalEntry, Tools::ListTrips,
  Tools::ListComments, Tools::ListReactions,
  # Phase 20 — Writes
  Tools::DeleteJournalEntry,
  Tools::UpdateComment, Tools::DeleteComment,
  Tools::CreateChecklist, Tools::UpdateChecklist,
  Tools::DeleteChecklist, Tools::CreateChecklistItem
].freeze
```

### 7.8 Updated `instructions_for(agent)`

```ruby
def self.instructions_for(agent)
  persona =
    if agent
      "You are #{agent.name}, an AI travel assistant"
    else
      "You are an AI travel assistant"
    end
  <<~TEXT
    #{persona} for the Trip Journal app.
    You can create, edit, and delete journal entries; attach images
    via URLs or upload them directly; add and remove emoji reactions;
    write, edit, and delete comments; create, rename, and delete
    checklists and add items to them; update trip details; transition
    trip states; and query trip status. When no trip_id is provided,
    you operate on the single currently active (started) trip. Trip
    creation and member administration are handled by humans.
  TEXT
end
```

---

## 8. Task List (ordered)

Execute top-to-bottom. Eleven atomic tool commits + 2 wrap-up commits. Each tool commit is independently revertable: tool file + spec + `TOOLS` registration + tool-count assertion bump (`12 → 13 → … → 23`) all land together, so reverting that single commit cleanly removes one tool with no broken tests.

### Pre-flight

0. **Read** `AGENTS.md`, `app/actions/CLAUDE.md`, `app/mcp/README.md`, and this PRP end-to-end.
1. **Confirm §4 decisions** and **§17 Open Questions are answered**.
2. **Open GitHub issue** titled "Phase 20 — Complete MCP Server (Content Curation)". Label `feature`. Move **Backlog → Ready → In Progress** on the Trip Kanban Board.
3. Create branch `feature/phase20-complete-mcp-server` off `main`.
4. **Subscriber audit (hard pre-flight gate — operator-confirmed):** grep `config/initializers/event_subscribers.rb` + `app/subscribers/**` for handlers on `comment.updated`, `comment.deleted`, `journal_entry.deleted`, `checklist.created/updated/deleted`, `checklist_item.created`. Confirm none email `@system.local` users. If any leak, fix the filter (or file a sub-issue and add to §14) **before** writing tool code. Do not proceed to commit 1 until this is clean.

### Per-commit recipe (applies to commits 1–11)

For each tool in the order below:

1. Create `app/mcp/tools/<tool>.rb` from the blueprint in §7 or the closest sibling tool.
2. Create `spec/mcp/tools/<tool>_spec.rb` covering: happy path, not-found, state-guard (if applicable), validation failure (if applicable).
3. Append the tool to `TripJournalServer::TOOLS` (preserve the §7.7 grouping comments — Reads block, Writes block).
4. Bump the tool-count assertion in `spec/mcp/trip_journal_server_spec.rb` by one.
5. Run `bundle exec rspec spec/mcp/` — green.
6. Run `bundle exec rake project:fix-lint` then `project:lint` on the changed files — clean.
7. Commit with the subject below; body explains *why* and lists the tool's purpose in one line.

### Tool commits (11)

| # | Tool | Commit subject | Section |
|---|------|----------------|---------|
| 1  | `get_journal_entry`     | `Add get_journal_entry MCP tool`     | §7.1 |
| 2  | `list_trips`            | `Add list_trips MCP tool`            | §6 inventory |
| 3  | `list_comments`         | `Add list_comments MCP tool`         | §7.2 |
| 4  | `list_reactions`        | `Add list_reactions MCP tool`        | §6 inventory |
| 5  | `delete_journal_entry`  | `Add delete_journal_entry MCP tool`  | §7.3 |
| 6  | `update_comment`        | `Add update_comment MCP tool`        | §7.4 |
| 7  | `delete_comment`        | `Add delete_comment MCP tool`        | §6 inventory |
| 8  | `create_checklist`      | `Add create_checklist MCP tool`      | §7.5 |
| 9  | `update_checklist`      | `Add update_checklist MCP tool`      | §6 inventory |
| 10 | `delete_checklist`      | `Add delete_checklist MCP tool`      | §6 inventory |
| 11 | `create_checklist_item` | `Add create_checklist_item MCP tool` | §7.6 |

After commit 11, the tool-count assertion in `trip_journal_server_spec.rb` reads `eq(23)`.

### Commit 12 — Server instructions refresh

a. Update `TripJournalServer.instructions_for` per §7.8 — mentions delete/edit capabilities and the "trip creation and member administration are handled by humans" disclaimer.
b. Update the existing instructions-text assertion in `spec/mcp/trip_journal_server_spec.rb` to match the new wording.
c. Run `bundle exec rspec spec/mcp/` — green.
d. Commit: **"Refresh MCP server instructions for Phase 20 capabilities"**.

### Commit 13 — Documentation

a. Update `app/mcp/README.md` — add rows in every section; replace "12 Tools" prose with "23 Tools"; note human-only carve-outs (trip creation, members, invitations) in a brief boundary section.
b. Update `docs/mcp-curl-cheatsheet.md` — one curl example per new tool, grouped by section, with the Phase-19 `X-Agent-Identifier` header.
c. Update `AGENTS.md` "12 registered MCP tools" → 23.
d. Update `prompts/PROJECT SUMMARY.md` line 31 — "23 tools".
e. Update `.claude/skills/trip-journal-mcp/SKILL.md` references.
f. Commit: **"Document Phase 20 MCP tools"**.

### Validate + ship

12. Run `bundle exec rake project:fix-lint` → `project:lint` across the full tree — clean.
13. Run `bundle exec rake project:tests` — full suite green.
14. Run `bundle exec rake project:system-tests` — full suite green.
15. Run §11 Runtime Test Checklist.
16. Push branch.
17. Open PR titled **"Phase 20 — Complete MCP Server"**, link the issue, summarise the 11 new tools + scope-out list. Move issue to **In Review**.
18. Respond to every review comment per `AGENTS.md` §4. Resolve threads.
19. After merge: move issue to **Done**. Smoke-test `tools/list` against production to confirm 23 tools listed.

---

## 9. Testing Strategy

### Unit (per tool)

For **every** new tool, the spec covers:

1. **Happy path** — valid input returns a `success_response` whose JSON body has the documented fields.
2. **Not-found** — invalid UUID returns `error_response("X not found: …")`.
3. **State guard** — if the tool has `require_writable!`, archived/finished trip rejection.
4. **Validation failure** — for write tools whose action can `Failure(errors)`, pass invalid input and assert the failure path.
5. **Idempotency / edge case** — where applicable (e.g. `delete_journal_entry` called twice).
6. **No-agent-attribution sanity check** — pass `_server_context: {}` and confirm the tool works (no Phase-20 write tool requires the agent).

### Server

- `spec/mcp/trip_journal_server_spec.rb`:
  - Tool count = 23.
  - Instructions text includes new capability keywords ("delete", "edit", "comments", "checklist") and the human-only disclaimer ("Trip creation and member administration are handled by humans").

### Request (no new request specs needed)

Existing `spec/requests/mcp_spec.rb` covers controller-level auth.

### Integration (manual curl in §11)

End-to-end through HTTP for at least one new tool from each category.

### Out of scope

- Browser UI tests (no UI surface added).
- Performance / load (11 thin tools; same characteristics as existing 12).

---

## 10. Validation Gates (Executable)

Per `AGENTS.md` §3:

```bash
bundle exec rake project:fix-lint
bundle exec rake project:lint
bundle exec rake project:tests
bundle exec rake project:system-tests
```

All four green before pushing. Overcommit hooks (RuboCop, whitespace, capitalised subject, no trailing period, body width) run on every commit.

---

## 11. Runtime Test Checklist

Per `AGENTS.md` §5 (mandatory before pushing):

1. **Rebuild + restart:**
   ```bash
   bin/cli app rebuild
   bin/cli app restart
   bin/cli mail start
   ```

2. **MCP endpoint — `tools/list`:**
   ```bash
   curl -s https://catalyst.workeverywhere.docker/mcp \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $MCP_API_KEY" \
     -H "X-Agent-Identifier: jack" \
     -d '{"jsonrpc":"2.0","id":"1","method":"tools/list"}' \
     | python3 -m json.tool | grep '"name"' | wc -l
   # expect: 23
   ```

3. **Per-domain smoke test:**

   - Read: `list_trips`
     ```bash
     curl -s … -d '{"jsonrpc":"2.0","id":"2","method":"tools/call","params":{"name":"list_trips","arguments":{}}}'
     ```
   - Read: `get_journal_entry` for a seeded entry.
   - Write: `delete_journal_entry` on a throwaway seeded entry, then verify it's gone:
     ```bash
     docker exec -i catalyst-app-dev bin/rails runner - <<'EOF'
       puts JournalEntry.exists?("<uuid>") ? "still here" : "gone"
     EOF
     ```
   - Write: `create_checklist` + `create_checklist_item` chained.
   - Write: `update_comment` + `delete_comment` on a seeded comment.

4. **State-guard smoke test** — archive a trip, attempt `delete_journal_entry` on one of its entries, confirm `error_response` with "not writable".

5. **Browser sweep** against `https://catalyst.workeverywhere.docker/`:
   - [ ] Home page renders (logged out + logged in).
   - [ ] Sign-in works.
   - [ ] Trip page reflects newly-created checklist.
   - [ ] No runtime errors.

6. **Mailcatcher sweep** — confirm no emails fire to `@system.local` users for any of the new tool invocations.

---

## 12. Documentation Updates

| File | Change |
|------|--------|
| `app/mcp/README.md` | Add table rows for all 11 new tools; replace "12 Tools" prose with "23 Tools"; note human-only carve-outs (trip creation, member administration, invitations). |
| `docs/mcp-curl-cheatsheet.md` | Add one curl example per new tool, grouped by section, with the Phase-19 `X-Agent-Identifier` header. |
| `AGENTS.md` | Update count: "12 registered MCP tools" → 23. |
| `prompts/PROJECT SUMMARY.md` | Line 31: "12 tools" → "23 tools". |
| `.claude/skills/trip-journal-mcp/SKILL.md` | Update tool inventory section. |

**Left alone:**
- `docs/mcp-architecture.excalidraw` — adding 11 boxes isn't worth the time.
- Historical `prompts/Phase N*.md` — append-only audit trail.

---

## 13. Rollback Plan

Phase 20 is purely additive: new files, new entries in a frozen array, no schema changes.

1. **Fast path (revert merge commit):** `git revert <merge sha>` and redeploy. No data implications.
2. **Partial rollback:** Remove individual tools from `TripJournalServer::TOOLS` and redeploy. Tool files can remain on disk dormant.
3. **No data rollback needed** — no migration to reverse.

---

## 14. Future Work (Out of Scope)

Documented here so Phase 20 reviewers understand the deliberate boundary:

1. **`create_trip` MCP tool.** Currently a human concern. If the operator later wants agents to scaffold trips, revisit — needs a decision on whether `created_by` is the agent's system user or a human owner.
2. **Member administration (`assign_trip_member`, `remove_trip_member`, `list_trip_members`).** Human-only by design. Revisit if agent workflows ever need to read membership (note: `get_trip_status` already returns `member_count`, which may be enough).
3. **`send_invitation`.** Same human-only boundary as #2.
4. **`request_export` MCP tool.** Needs operator decision on `Export#user_id` semantics.
5. **Image management.** Need new `JournalEntries::DetachImage` + `ReplaceImage` actions.
6. **Checklist item update / delete.** Need new `ChecklistItems::Update` + `Delete` actions.
7. **Checklist section CRUD.** New domain layer.
8. **`Trips::Delete`.** Trips are state-machined, not destroyed. Add the action only if hard delete is genuinely needed.
9. **Per-trip agent grants (Phase-19 Phase 2).** New tools will automatically respect the eventual grant table.
10. **Admin UI for agent + trip-member management.** Web-side, not MCP-side.

---

## 15. Reference Documentation

### In-repo

- `app/mcp/README.md` — current MCP surface
- `app/actions/CLAUDE.md` — action pattern + event names inventory
- `AGENTS.md` — full governance + CLI + PR review rules
- `prompts/Phase 19 - Agent Identity - Phase 1 - PRP.md` — agent identity model
- `prompts/PROJECT SUMMARY.md` — stack overview

### Existing tool exemplars

- `app/mcp/tools/update_trip.rb`
- `app/mcp/tools/toggle_checklist_item.rb`
- `app/mcp/tools/list_journal_entries.rb`
- `app/mcp/tools/create_journal_entry.rb`
- `app/mcp/tools/get_trip_status.rb`

### MCP / spec

- MCP specification: <https://modelcontextprotocol.io/specification>
- MCP Ruby SDK: <https://github.com/modelcontextprotocol/ruby-sdk>
- JSON-RPC 2.0: <https://www.jsonrpc.org/specification>

### Ruby / Rails

- Rails 8.1 guides: <https://guides.rubyonrails.org/>
- Active Record query interface: <https://guides.rubyonrails.org/active_record_querying.html>
- Dry::Monads: <https://dry-rb.org/gems/dry-monads/>
- RSpec-rails: <https://rspec.info/documentation/latest/rspec-rails/>
- FactoryBot: <https://thoughtbot.github.io/factory_bot/>

---

## 16. Skill Self-Evaluation

**Skill used:** `generate-prp`

**Step audit:**
- Codebase analysis covered all 12 existing tools and the underlying actions for the new ones.
- External research was light; URLs were canonical from Phase 19.
- I did **not** open `config/initializers/event_subscribers.rb` to verify §5 Gotcha 11 — queued instead as Step 4 of the task list and §17 Q3. Better answered with a grep at execution time than blocking the plan now.
- Output target was overridden from `PRPs/<feature>.md` to `prompts/Phase 20 Complete MCP Server.md` per the user's explicit instruction.
- After v1 scope discussion, dropped 5 tools (trip creation, member admin ×3, invitations) per user direction. Plan is now tighter and more confidently one-pass.

**Improvement suggestion:** The `generate-prp` skill could prompt the author to explicitly mark which operations are **deliberately human-only** vs. **technically deferred** — this distinction matters for how the user thinks about future scope, and bare "out of scope" lists conflate the two. Phase 20's §2 / §14 now make that distinction; the skill template should encourage it for every PRP.

---

## 17. Open Questions for the Operator

All questions resolved (operator answered 2026-05-14):

| # | Question | Decision |
|---|----------|----------|
| 1 | `get_journal_entry` body format | **HTML** (`body.to_s`) — formatting matters |
| 2 | `list_comments` author field | **Keep both** `author_email` + `author_name` |
| 3 | Subscriber audit timing | **Hard pre-flight gate** — §8 Step 4 must pass before any tool code is written |
| 4 | Commit grouping | **11 atomic commits**, one per tool (+ 2 wrap-up) |
| 5 | `list_trips` scope | **Include archived trips** — return all |
| 6 | `position` parameter on checklist tools | **Allow** on create/update/create-item |

---

**STOP — plan complete. Awaiting operator approval before any code is written.**
