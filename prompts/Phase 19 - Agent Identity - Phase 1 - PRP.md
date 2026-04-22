# PRP: Phase 19 — Agent Identity, Phase 1 (Registered Agents)

**Status:** Draft
**Date:** 2026-04-22
**Type:** Feature + Refactor (Phase 1.5 cleanup bundled)
**Confidence Score:** 8/10

One-pass implementation confidence is high: every touch point is already mapped, existing patterns (Actions + Dry::Monads, UUID PKs via `sqlite_crypto`, `server_context` plumbing, factory-based specs) cover the new code end-to-end, and the scope is deliberately narrow. The one reason it isn't 9/10 is the deploy-sequence coupling (header requirement + existing Claude Desktop configs must be updated in lockstep) — an AI can plan the steps but must flag it loudly in the PR description so the human operator doesn't forget.

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Goals and Non-Goals](#2-goals-and-non-goals)
3. [Design Decisions Resolved](#3-design-decisions-resolved)
4. [Codebase Context](#4-codebase-context)
5. [Data Model](#5-data-model)
6. [Implementation Blueprint](#6-implementation-blueprint)
7. [Task List (ordered)](#7-task-list-ordered)
8. [Testing Strategy](#8-testing-strategy)
9. [Validation Gates (Executable)](#9-validation-gates-executable)
10. [Runtime Test Checklist](#10-runtime-test-checklist)
11. [Deployment Plan](#11-deployment-plan)
12. [Documentation Updates](#12-documentation-updates)
13. [Rollback Plan](#13-rollback-plan)
14. [Future Work (Phases 2 and 3)](#14-future-work-phases-2-and-3)
15. [Reference Documentation](#15-reference-documentation)
16. [Skill Self-Evaluation](#16-skill-self-evaluation)

---

## 1. Problem Statement

The MCP server hardcodes "Jack" as **the** AI actor across three surfaces:

| Surface | File | Line(s) | Hardcoding |
|---------|------|---------|------------|
| Attribution (DB) | `app/mcp/tools/base_tool.rb` | 51-56 | `resolve_jack_user` → `User.find_or_create_by!(email: "jack@system.local", name: "Jack")` |
| Persona (instructions) | `app/mcp/trip_journal_server.rb` | 19-26 | `"You are Jack, an AI travel assistant…"` |
| Tool parameters | `app/mcp/tools/create_journal_entry.rb` | 33-39, 51 | `actor_type` default `"Jack"`, `actor_id` default `"jack"` |
| Enum constant | `app/mcp/tools/base_tool.rb` | 7 | `VALID_ACTOR_TYPES = %w[Jack System]` |

The user runs **a dedicated agent per trip** (e.g. `Marée` for one trip, `Jack` as a general assistant). Because the server tells every connecting agent "You are Jack" in its `initialize` instructions, Marée talks like Jack, signs journal entries as Jack, and the user receives notifications *from Jack* about Marée's work. This is both functionally confusing and breaks the one-agent-per-trip mental model the user wants.

Phase 1 introduces a first-class `Agent` record so every agent has its own identity — name, slug, and system User — and the MCP server resolves which agent is speaking from an HTTP header on each request. Phase 2 (per-trip pairing keys) and Phase 3 (OAuth) are intentionally out of scope.

---

## 2. Goals and Non-Goals

### Goals (Phase 1 + Phase 1.5)

1. First-class `Agent` model with `slug` (stable identifier) and `name` (display), owning exactly one system `User`.
2. MCP requests carry an `X-Agent-Identifier: <slug>` header that the controller resolves to an `Agent` and injects into `server_context`.
3. All write tools (`create_journal_entry`, `create_comment`, `add_reaction`) record the resolved Agent's User as author/user.
4. `TripJournalServer::INSTRUCTIONS` is parameterised by the resolved Agent's name — *"You are <Name>, an AI travel assistant…"*.
5. **Phase 1.5 cleanup:** remove `actor_type`/`actor_id` tool parameters and the `VALID_ACTOR_TYPES`/`validate_actor_type!` scaffolding. The resolved Agent is the single source of attribution.
6. Backfill existing `jack@system.local` user into an `Agent(slug: "jack", name: "Jack")` row via data migration so production deploys seamlessly.
7. Seeds gain a second agent (Marée) so development mirrors the multi-agent reality.

### Non-Goals (explicit)

- **Phase 2:** per-trip pairing keys / `agent_trip_grants` table — not in this PRP.
- **Phase 3:** OAuth / dynamic client registration — not in this PRP.
- **Admin UI:** Agent CRUD via web page. For Phase 1, seeds + Rails console are the management surface. (Admin UI becomes more useful in Phase 2 when per-trip keys are generated.)
- **Dropping `journal_entries.actor_type` / `actor_id` columns.** The columns already hold historical data for existing rows; stop *writing* to them, but leave the columns in the schema. A follow-up cleanup migration can drop them once the team is confident no reader depends on them.
- **Backwards-compat fallback** for requests missing the header. Hard break (clear error message). The user is the sole operator and will update their Claude Desktop configs in the same PR.
- **Changing the Bearer-token auth mechanism.** `MCP_API_KEY` stays exactly as it is — the shared channel secret is unchanged, as the user requested.
- **Renaming the `jack@system.local` user** or its email. Only the Agent wrapper is new; the existing User keeps its email so foreign keys in production are untouched.

---

## 3. Design Decisions Resolved

All decisions below are the user's explicit choices from the brainstorming conversation (see `prompts/Phase 19 - Agent Identity Brainstorming.md`).

| # | Decision | Chosen | Rationale |
|---|----------|--------|-----------|
| 1 | Identity mechanism | **Registered** (not asserted) | Phase 2 needs stable Agent rows to hang trip keys off; model it up front. Prevents duplicate records from typo'd names. |
| 2 | Agent ↔ User association | `Agent belongs_to :user` (FK on `agents.user_id`, unique) | User table stays untouched (no `agent_id` column, no `system_actor` flag). User doesn't know about Agent. Semantically Agent "owns" the User; Rails FK placement is the implementation. |
| 3 | How identity is carried on the wire | HTTP header `X-Agent-Identifier: <slug>` | Set once in Claude Desktop config (same place as the Bearer token). Stateless — no session state needed. Doesn't pollute every tool's parameter schema. |
| 4 | Missing/unknown identifier response | JSON-RPC error in the response body (HTTP 200 with `error` object), **not** HTTP 401 | Matches the user's preference that agents get a *readable message* from the MCP layer rather than being stuck in confusing HTTP auth failures. 401 is reserved for Bearer-token failures only. |
| 5 | `actor_type` / `actor_id` tool parameters | **Remove** (Phase 1.5) | Redundant once identity is server-resolved; they're an artifact of the hardcoded-Jack era. Client-supplied attribution strings create ambiguity. |
| 6 | `VALID_ACTOR_TYPES` constant + `validate_actor_type!` guard | **Delete** | Unused once parameters above are gone. |
| 7 | `journal_entries.actor_type` / `actor_id` DB columns | **Keep** in schema, **stop writing** | Preserves historical rows; avoids a destructive migration. Future phase can drop them. |
| 8 | `INSTRUCTIONS` text | Templated: `"You are #{agent.name}, an AI travel assistant…"` | Agent persona injected from resolved record. |
| 9 | Existing Jack user in production | Data migration wraps `jack@system.local` in `Agent(slug: "jack", name: "Jack")` | Zero-touch for existing prod data; idempotent. |
| 10 | Seeds | Add Marée user (`maree@system.local`) + `Agent(slug: "maree", name: "Marée")` | Multi-agent reality baked into dev/test. |
| 11 | Admin UI | Out of scope Phase 1 | YAGNI for 2 agents; Rails console covers creation. |

---

## 4. Codebase Context

### Key Files (current state)

| File | Role in Phase 1 | Current Hardcoding |
|------|-----------------|---------------------|
| `app/controllers/mcp_controller.rb` | **MODIFY** — read header, resolve Agent, inject into `server_context` | L10-12 pass only `request_id` |
| `app/mcp/trip_journal_server.rb` | **MODIFY** — `INSTRUCTIONS` templated from `server_context[:agent]` | L19-26 hardcoded "Jack" |
| `app/mcp/tools/base_tool.rb` | **MODIFY** — `resolve_jack_user` → `resolve_agent_user(server_context)`; delete `VALID_ACTOR_TYPES` + `validate_actor_type!` | L7, L51-56, L76-82 |
| `app/mcp/tools/create_journal_entry.rb` | **MODIFY** — drop `actor_type`/`actor_id` params; un-underscore `_server_context`; pass to `resolve_agent_user` | L30-39, L48-65, L76-82 |
| `app/mcp/tools/create_comment.rb` | **MODIFY** — un-underscore `_server_context`; use `resolve_agent_user` | L22-23, L49-54 |
| `app/mcp/tools/add_reaction.rb` | **MODIFY** — un-underscore `_server_context`; use `resolve_agent_user` | L22, L25-27 |
| `db/seeds.rb` | **MODIFY** — add Marée user + both Agent rows (idempotent) | L76-80 creates Jack user only |
| `spec/requests/mcp_spec.rb` | **MODIFY** — add default header in `let(:headers)`; new tests for missing/unknown header | L6-19 |
| `spec/mcp/tools/create_journal_entry_spec.rb` | **MODIFY** — pass `_server_context: { agent: }`; remove `actor_type`/`actor_id` from args; assert author matches agent | L9-27 |
| `spec/mcp/tools/create_comment_spec.rb` | **MODIFY** — pass `_server_context: { agent: }` to every `described_class.call` | all specs |
| `spec/mcp/tools/add_reaction_spec.rb` | **MODIFY** — pass `_server_context: { agent: }` | all specs |
| `spec/mcp/trip_journal_server_spec.rb` | **MODIFY** — `"includes server instructions"` currently asserts `"Jack"`; update to assert presence of the agent name passed in `server_context` | L30-32 |
| `spec/factories/users.rb` | **MODIFY** — add `:system_actor` trait for `@system.local` emails | L4-22 |
| `docs/mcp-curl-cheatsheet.md` | **MODIFY** — add `X-Agent-Identifier` header to all curl examples; remove `actor_type`/`actor_id` from `create_journal_entry` args note | L145 |
| `app/mcp/README.md` | **MODIFY** — replace "Jack system actor" language with "registered agent" model; update `API Key Scope` section; update architecture ASCII (L22-26) | L23, L42 |
| `AGENTS.md` | **MODIFY** — the "MCP API Key Scope" section (L116) is now wrong (Jack is no longer *the* actor) | L116 |
| `README.md` | **MODIFY** — L237 mention of Jack as sole actor | L237 |
| `.claude/skills/trip-journal-mcp/SKILL.md` | **MODIFY** — agent identity docs | L40 |

### Reference Files (read-only — patterns to mirror)

| File | Pattern |
|------|---------|
| `app/actions/CLAUDE.md` | Actions + Dry::Monads pattern; event emission; error handling conventions |
| `app/actions/journal_entries/create.rb` | `system_actor?(user)` filter (L35-37) uses `email.end_with?("@system.local")` — **Marée's email must follow this convention so subscription filtering continues to work** |
| `db/migrate/20260322200003_create_journal_entries.rb` | Reference migration style — `id: :uuid`, `t.references :x, type: :uuid, null: false, foreign_key: true`, `t.timestamps` |
| `app/models/user.rb` | Model style — frozen_string_literal, `has_many` with explicit `foreign_key`, `inverse_of`, `dependent` |
| `app/models/trip.rb` | Enum + validation patterns |
| `spec/factories/users.rb` | Factory style with sequence + traits |
| `spec/mcp/tools/create_journal_entry_spec.rb` | Tool spec shape — `described_class.call(...)`, `JSON.parse(result.content.first[:text])` |
| `spec/requests/mcp_spec.rb` | Request spec auth header pattern — mock `ENV.fetch("MCP_API_KEY", nil)` |

### Critical Gotchas

1. **UUID primary keys everywhere.** This project uses `sqlite_crypto` gem (see `Gemfile:15`) which auto-generates UUIDs for PKs. Migrations **must** use `id: :uuid` and references **must** use `type: :uuid`. Do not use integer IDs.

2. **Rodauth verified status.** User records created for system actors need `status = 2` (Rodauth verified). See `db/seeds.rb:19` (`create_user` helper does this) and `base_tool.rb:51-56` (`resolve_jack_user` did this inline). New agent User creation in seeds must set this; the Agent backfill migration creates the Agent wrapper only — User already exists with status 2 in prod.

3. **System-actor email convention.** `JournalEntries::Create#subscribe_trip_members` (app/actions/journal_entries/create.rb:23-33) filters subscribers by `email LIKE "%@system.local"`. **Marée's email must end with `@system.local`** or she will auto-subscribe herself to her own entries and generate pointless notifications (the Phase 15 QA review flagged this already for Jack). Enforce by convention and document in the Agent model.

4. **MCP statelessness.** The server is rebuilt per HTTP request (`mcp_controller.rb:10-12`). There is no session — every request must carry its own `X-Agent-Identifier` header. Do not try to cache agent identity across requests.

5. **`ActiveSupport::SecurityUtils.secure_compare`** requires strings of equal length. The existing bearer-token compare handles this. Agent slug resolution is a simple `find_by(slug:)` — no secure-compare needed (slugs are not secrets).

6. **Controller must distinguish HTTP 401 from JSON-RPC errors.**
   - Bearer-token failure → HTTP 401 (unchanged).
   - Missing/unknown `X-Agent-Identifier` → HTTP 200 with `{jsonrpc:"2.0", id:null, error:{code:-32001, message:"..."}}`. This is the user's explicit preference (decision #4).

7. **`VALID_ACTOR_TYPES` is also referenced in `create_journal_entry.rb:34` as the enum for the `actor_type` property.** When that parameter is removed in Phase 1.5, both the constant and the enum reference disappear together.

8. **`spec/mcp/trip_journal_server_spec.rb:31`** asserts `INSTRUCTIONS.include?("Jack")`. When INSTRUCTIONS becomes parameterised (set on `build(server_context:)` rather than a frozen class constant), this assertion has to change shape — instructions will be derived from the Agent passed in context.

9. **MCP gem version.** `Gemfile:49` pins `gem "mcp", "~> 0.13"`. The gem's `MCP::Server.new(..., server_context:, tools:)` API is already in use. No version bump needed.

10. **Overcommit + RuboCop.** Pre-commit hook runs RuboCop (`rubocop-rails-omakase`). Run `bundle exec rake project:fix-lint` before committing. Migration files with `Metrics/MethodLength` complaints happen — use heredoc or comments as needed, not `rubocop:disable`.

11. **Overcommit schema hook.** New migrations update `db/schema.rb`. Run `bundle exec rails db:migrate` locally before committing or the `RailsSchemaUpToDate` hook fails. Commit the schema change in the same commit as the migration.

---

## 5. Data Model

### New Table: `agents`

```ruby
# db/migrate/TIMESTAMP_create_agents.rb
class CreateAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :agents, id: :uuid do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.text :description
      t.references :user, type: :uuid, null: false,
                          foreign_key: true, index: { unique: true }
      t.timestamps
    end
    add_index :agents, :slug, unique: true
  end
end
```

**Why these columns only:**
- `slug` — the stable, URL-safe identifier agents send in the `X-Agent-Identifier` header. Lowercase, `[a-z0-9_-]`.
- `name` — display name (can include accents, e.g. `Marée`). Used in INSTRUCTIONS + any future UI.
- `description` — optional free-text for admin context. Not exposed to MCP clients.
- `user_id` — FK to the system User that owns all DB writes attributed to this agent.

**Explicitly excluded for Phase 1:** `api_key_digest`, `color`, `emoji`, `tone`, `default`, any Phase-2/3 fields. Add them when they're actually needed.

### New Data Migration: backfill Jack

```ruby
# db/migrate/TIMESTAMP_backfill_jack_agent.rb
class BackfillJackAgent < ActiveRecord::Migration[8.1]
  def up
    jack_user = User.find_by(email: "jack@system.local")
    return unless jack_user

    Agent.find_or_create_by!(slug: "jack") do |a|
      a.name = "Jack"
      a.user = jack_user
    end
  end

  def down
    Agent.find_by(slug: "jack")&.destroy
  end
end
```

Idempotent. Safe to re-run. In environments without Jack (fresh DB), this no-ops; seeds handle Jack creation from scratch.

### Model: `Agent`

```ruby
# app/models/agent.rb
class Agent < ApplicationRecord
  SLUG_FORMAT = /\A[a-z0-9_\-]+\z/

  belongs_to :user

  validates :slug, presence: true,
                   uniqueness: { case_sensitive: false },
                   format: { with: SLUG_FORMAT }
  validates :name, presence: true
  validates :user_id, uniqueness: true

  def self.find_by_slug(slug)
    find_by("LOWER(slug) = ?", slug.to_s.downcase)
  end
end
```

**Note on the association:** `Agent belongs_to :user` means the FK lives on the `agents` table (`agents.user_id`). `User` is unchanged — no `agent_id` column, no `has_one :agent` declaration. This is deliberate: the User table serves both humans and agents, so it shouldn't reference back to Agent. If cascade delete is ever needed, add it to the Agent model (destroying an Agent doesn't destroy its User today — destruction is manual via Rails console, which is fine for Phase 1).

---

## 6. Implementation Blueprint

### 6.1 Controller flow (end state)

```ruby
# app/controllers/mcp_controller.rb
class McpController < ActionController::API
  before_action :authenticate_api_key!
  before_action :validate_content_type!

  def handle
    body = request.body.read
    JSON.parse(body)

    agent = resolve_agent
    return render_agent_error("missing") if agent_slug.blank?
    return render_agent_error("unknown", agent_slug) if agent.nil?

    server = TripJournalServer.build(
      server_context: { request_id: request.uuid, agent: agent }
    )
    render json: server.handle_json(body)
  rescue JSON::ParserError
    render json: parse_error_payload, status: :ok
  end

  private

  # ... existing authenticate_api_key! and validate_content_type! unchanged ...

  def agent_slug
    @agent_slug ||= request.headers["X-Agent-Identifier"].to_s.strip
  end

  def resolve_agent
    return nil if agent_slug.blank?
    Agent.find_by_slug(agent_slug)
  end

  def render_agent_error(kind, slug = nil)
    message =
      case kind
      when "missing"
        "Missing X-Agent-Identifier header. Configure your MCP client " \
        "with the slug of your registered agent (e.g. 'jack')."
      when "unknown"
        "Agent '#{slug}' is not registered. Ask the admin to create " \
        "an Agent record with this slug."
      end
    render json: {
      jsonrpc: "2.0", id: nil,
      error: { code: -32_001, message: message }
    }, status: :ok
  end

  def parse_error_payload
    { jsonrpc: "2.0", id: nil,
      error: { code: -32_700, message: "Parse error" } }
  end
end
```

**Error code `-32001`** — JSON-RPC reserves `-32000..-32099` for "implementation-defined server errors." `-32001` signals "agent resolution failed." Clients that understand JSON-RPC will render the `message` field, which is what the user wanted: a readable error instead of opaque 401.

### 6.2 Server builder (end state)

```ruby
# app/mcp/trip_journal_server.rb
class TripJournalServer
  TOOLS = [...].freeze  # unchanged

  def self.build(server_context: {})
    agent = server_context[:agent]
    MCP::Server.new(
      name: "trip_journal",
      version: "1.0.0",
      instructions: instructions_for(agent),
      tools: TOOLS,
      server_context: server_context
    )
  end

  def self.instructions_for(agent)
    name = agent&.name || "an AI travel assistant"
    <<~TEXT
      You are #{name}, an AI travel assistant for the Trip Journal app.
      You can create and manage journal entries, attach images via URLs
      or upload them directly as base64-encoded data, add comments and
      reactions, update trip details, transition trip states, toggle
      checklist items, and query trip status. When no trip_id is
      provided, you operate on the single currently active (started) trip.
    TEXT
  end
end
```

The `agent&.name` fallback covers tests and edge paths that build the server without injecting an agent. In normal production flow, the controller ensures `agent` is present before calling `build`.

### 6.3 Base tool (end state)

```ruby
# app/mcp/tools/base_tool.rb
module Tools
  class BaseTool < MCP::Tool
    class ToolError < StandardError; end

    # -- Response helpers (unchanged) --
    # ... success_response, error_response ...

    # -- Trip resolution (unchanged) --
    # ... resolve_trip ...

    private_class_method def self.resolve_agent_user(server_context)
      agent = server_context&.dig(:agent)
      raise ToolError, "No agent in server context" if agent.nil?
      agent.user
    end

    # -- Guards (require_writable!, require_commentable! unchanged) --
    # -- validate_actor_type! DELETED (along with VALID_ACTOR_TYPES) --
  end
end
```

No more `find_or_create_by!` — the agent is pre-registered, so the User must already exist. A missing `:agent` key in `server_context` is a programmer error (indicates the controller didn't populate it), hence `ToolError` rather than a graceful fallback.

### 6.4 Tool changes (write paths)

**`create_journal_entry.rb`** — remove `actor_type`/`actor_id` params entirely:

```ruby
input_schema(
  properties: {
    trip_id: { type: "string", description: "..." },
    name: { type: "string", description: "Entry title" },
    body: { type: "string", description: "..." },
    entry_date: { type: "string", description: "..." },
    location_name: { type: "string", description: "..." },
    description: { type: "string", description: "..." },
    telegram_message_id: { type: "string", description: "..." }
    # actor_type and actor_id REMOVED
  },
  required: %w[name entry_date]
)

def self.call(name:, entry_date:, trip_id: nil, body: nil,
              location_name: nil, description: nil,
              telegram_message_id: nil, server_context: {})
  trip = resolve_trip(trip_id)
  require_writable!(trip)
  idempotent_check(trip, telegram_message_id) || create_entry(
    trip: trip, name: name, entry_date: entry_date, body: body,
    location_name: location_name, description: description,
    telegram_message_id: telegram_message_id,
    user: resolve_agent_user(server_context)
  )
rescue ToolError => e
  error_response(e.message)
end
```

Note `_server_context` → `server_context` (un-underscored) and the extra `user:` argument passed to `create_entry`. The downstream `JournalEntries::Create.new.call(params:, trip:, user:)` is unchanged — it already takes `user:`. Just stop passing `actor_type`/`actor_id` into `params`.

**`entry_response`** — also drop `actor_type` from the returned JSON:

```ruby
private_class_method def self.entry_response(entry)
  success_response(
    id: entry.id, name: entry.name,
    entry_date: entry.entry_date.to_s,
    location_name: entry.location_name,
    trip_id: entry.trip_id
  )
end
```

**`create_comment.rb`** and **`add_reaction.rb`** — identical shape: un-underscore `server_context`, call `resolve_agent_user(server_context)` in place of `resolve_jack_user`. No parameter schema changes.

### 6.5 Seeds (idempotent agent block)

Append after the existing Jack user creation (`db/seeds.rb:76-80`):

```ruby
maree = create_user(
  email: "maree@system.local",
  name: "Marée", roles: []
)
log "System actor: #{maree.email}"

# Agents
Agent.find_or_create_by!(slug: "jack") do |a|
  a.name = "Jack"
  a.user = jack
end
Agent.find_or_create_by!(slug: "maree") do |a|
  a.name = "Marée"
  a.user = maree
end
log "Agents: #{Agent.pluck(:slug).join(', ')}"
```

### 6.6 Spec shape

**`spec/requests/mcp_spec.rb`** — add an Agent record and default header:

```ruby
let(:agent) { create(:agent, slug: "jack") }

let(:headers) do
  {
    "Authorization" => "Bearer #{api_key}",
    "Content-Type" => "application/json",
    "X-Agent-Identifier" => agent.slug
  }
end

context "without X-Agent-Identifier header" do
  it "returns JSON-RPC error -32001" do
    post "/mcp", params: init_payload, headers: headers.except("X-Agent-Identifier")
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["error"]["code"]).to eq(-32_001)
    expect(body["error"]["message"]).to include("X-Agent-Identifier")
  end
end

context "with unknown agent slug" do
  it "returns JSON-RPC error -32001 with a helpful message" do
    post "/mcp", params: init_payload,
         headers: headers.merge("X-Agent-Identifier" => "ghost")
    expect(response.parsed_body["error"]["message"]).to include("'ghost'")
  end
end
```

**`spec/mcp/tools/create_journal_entry_spec.rb`** — remove `actor_type`/`actor_id`, add `server_context`:

```ruby
let!(:trip) { create(:trip, :started) }
let(:agent) { create(:agent) }

describe ".call" do
  it "creates a journal entry attributed to the agent's user" do
    result = described_class.call(
      name: "Day 1 in Paris",
      entry_date: Date.current.to_s,
      trip_id: trip.id,
      server_context: { agent: agent }
    )
    expect(result).to be_a(MCP::Tool::Response)
    entry = JournalEntry.find(JSON.parse(result.content.first[:text])["id"])
    expect(entry.author).to eq(agent.user)
  end
  # ... other specs similarly accept server_context ...
end
```

**`spec/factories/agents.rb` (new):**

```ruby
FactoryBot.define do
  sequence(:agent_slug) { |n| "agent#{n}" }

  factory :agent do
    slug { generate(:agent_slug) }
    name { slug.capitalize }
    association :user, :system_actor
  end
end
```

**`spec/factories/users.rb`** — add trait so Agent factory produces a valid `@system.local` user:

```ruby
trait :system_actor do
  sequence(:email) { |n| "agent#{n}@system.local" }
  name { "System Actor" }
end
```

---

## 7. Task List (ordered)

Execute top-to-bottom. Each task is atomic and commitable on its own; the final commit bundles test/doc updates so the working tree is always green.

### Pre-flight

0. **Read** `AGENTS.md`, `app/actions/CLAUDE.md`, and `prompts/Phase 19 - Agent Identity Brainstorming.md`. Open a GitHub issue titled **"Phase 19 Phase 1 — Agent Identity (Registered Agents)"**, add the `enhancement` label, move to **Ready**, then **In Progress**. Create branch `feature/phase19-agent-identity` off `main`.

### Data layer

1. **Generate migration `create_agents`** with the schema from §5. Run `bin/cli db migrate dev` (or `bundle exec rails db:migrate`). Verify `db/schema.rb` updated.
2. **Generate data migration `backfill_jack_agent`** with the backfill logic from §5.
3. **Create `app/models/agent.rb`** per §5.
4. **Create `spec/models/agent_spec.rb`** covering: slug presence/format/uniqueness, name presence, user uniqueness, association loading.
5. **Create `spec/factories/agents.rb`** + add `:system_actor` trait to `spec/factories/users.rb` per §6.6.
6. **Run `bundle exec rspec spec/models/agent_spec.rb`** — must pass.

### MCP server

7. **Modify `app/controllers/mcp_controller.rb`** — add `resolve_agent`, `render_agent_error`, integrate into `#handle` per §6.1. Keep `authenticate_api_key!` untouched (Bearer auth unchanged per decision #11).
8. **Modify `app/mcp/trip_journal_server.rb`** — parameterise `INSTRUCTIONS` via `instructions_for(agent)` per §6.2.
9. **Modify `app/mcp/tools/base_tool.rb`** — replace `resolve_jack_user` with `resolve_agent_user`; delete `VALID_ACTOR_TYPES` + `validate_actor_type!` per §6.3.

### Tools (write paths)

10. **Modify `app/mcp/tools/create_journal_entry.rb`** — drop `actor_type`/`actor_id` params, un-underscore `server_context`, pass `user: resolve_agent_user(server_context)` per §6.4. Drop `actor_type` from `entry_response` JSON.
11. **Modify `app/mcp/tools/create_comment.rb`** — un-underscore `server_context`, swap `resolve_jack_user` → `resolve_agent_user(server_context)`.
12. **Modify `app/mcp/tools/add_reaction.rb`** — same pattern as step 11.

### Tests

13. **Update `spec/requests/mcp_spec.rb`** — create an Agent in `let!`, include `X-Agent-Identifier` in default headers, add two new contexts (missing header → `-32001`, unknown slug → `-32001`).
14. **Update `spec/mcp/tools/create_journal_entry_spec.rb`** — accept `server_context: { agent: agent }` in every `.call`; remove `actor_type`/`actor_id` args + assertions; assert `entry.author == agent.user`.
15. **Update `spec/mcp/tools/create_comment_spec.rb`** — add `server_context: { agent: agent }` to every `.call`.
16. **Update `spec/mcp/tools/add_reaction_spec.rb`** — same as step 15.
17. **Update `spec/mcp/trip_journal_server_spec.rb`** — change the `"includes server instructions"` assertion: build with `server_context: { agent: agent }`, assert instructions include the agent's name.

### Data + bootstrap

18. **Update `db/seeds.rb`** — add Marée user, add Agent creation block per §6.5. Run `bin/cli db reset dev` and verify both agents present (`bin/rails runner 'puts Agent.pluck(:slug)'`).

### Documentation

19. **Update `docs/mcp-curl-cheatsheet.md`** — add `X-Agent-Identifier: jack` header to every curl example (add to template at L27-44, update every example below); delete the `actor_type`/`actor_id` note at L145.
20. **Update `app/mcp/README.md`** — replace "Jack system actor" language with "registered agent" model; rewrite **API Key Scope** section (L40-48); update architecture ASCII (L22-26) — drop `validate_actor_type` reference.
21. **Update `README.md`** L237 — remove sole-Jack-actor language; mention agent registration.
22. **Update `AGENTS.md`** — rewrite the **MCP API Key Scope** section (L116) to describe the two-layer model: Bearer token (channel) + Agent header (attribution). Explicitly note: `MCP_API_KEY` is unchanged.
23. **Update `.claude/skills/trip-journal-mcp/SKILL.md`** L40 — match new wording.

### Validation + ship

24. **Run `bundle exec rake project:fix-lint`** then `project:lint` — both clean.
25. **Run `bundle exec rake project:tests`** — all green (incl. new agent_spec, mcp_spec, tool specs).
26. **Run `bundle exec rake project:system-tests`** — all green.
27. **Runtime verification** — see §10.
28. **Commit atomically** (recommended split):
    - Commit 1: migration + Agent model + spec/factory (steps 1-6)
    - Commit 2: controller + server + base_tool changes (steps 7-9)
    - Commit 3: tool changes (steps 10-12)
    - Commit 4: spec updates (steps 13-17)
    - Commit 5: seeds (step 18)
    - Commit 6: docs (steps 19-23)

    Each commit message capitalised, no trailing period, body explains *why*.

29. **Push branch**, open PR titled *"Phase 19 Phase 1 — Agent Identity (Registered Agents)"*, reference the issue in description. Move issue to **In Review**.
30. **Respond to PR review comments** per AGENTS.md §4 PR Review Response Rules.
31. **After merge**, move issue to **Done**. Update local Claude Desktop configs for Jack and Marée to include `X-Agent-Identifier` header (see §11 Deployment Plan). Verify in production.

---

## 8. Testing Strategy

### Unit

- **`Agent` model** — validations (slug format, uniqueness, presence), association loading, `find_by_slug` downcasing.

### Request (controller)

- **`McpController#handle`** — five branches:
  1. Missing Bearer token → 401 (unchanged).
  2. Wrong Bearer token → 401 (unchanged).
  3. Valid Bearer + missing `X-Agent-Identifier` → 200 with JSON-RPC error -32001.
  4. Valid Bearer + unknown slug → 200 with JSON-RPC error -32001.
  5. Valid Bearer + valid slug → 200, `server_context[:agent]` populated, tool dispatch works.

### Tool

- **`Tools::CreateJournalEntry`** — attribution goes to `agent.user`; missing `actor_type`/`actor_id` args don't break the tool (they're gone); idempotency still works per existing telegram_message_id spec.
- **`Tools::CreateComment`** — comment's `user` == `agent.user`.
- **`Tools::AddReaction`** — reaction's `user` == `agent.user`.
- **Missing `server_context[:agent]`** — `resolve_agent_user` raises `ToolError`, tool returns error response. (Edge case; should never happen via controller flow, but guard against programmer error.)

### Server

- **`TripJournalServer.build`** — instructions include the agent's name when context carries an agent; fall back to generic phrasing when not.
- **Existing 12-tools assertion** — unchanged.

### Integration (end-to-end through HTTP)

- **`initialize` JSON-RPC call** — response includes server info; instructions reflect the agent slug provided in the header.
- **`tools/call` create_journal_entry via HTTP with `X-Agent-Identifier: maree`** — created entry's `author.email` is `maree@system.local`.

### Not tested (out of scope)

- UI for agent management (no UI exists yet).
- Multiple simultaneous agent requests (each request is independent; no shared state).

---

## 9. Validation Gates (Executable)

Per `AGENTS.md` §3 Pre-Commit Validation:

```bash
# Lint (autocorrect then verify)
bundle exec rake project:fix-lint
bundle exec rake project:lint

# Unit + request specs
bundle exec rake project:tests

# System specs (headless browser)
bundle exec rake project:system-tests
```

All four must be green before pushing. Overcommit will run RuboCop + whitespace checks + `RailsSchemaUpToDate` on every commit — that last one is why the migration + schema.rb must land together.

Ruby command activation: the session's `ruby-version-manager` skill has already set up the Ruby environment, so `bundle exec …` works directly. In a fresh shell, re-run the skill's detect script before any Ruby command.

---

## 10. Runtime Test Checklist

Per `AGENTS.md` §5 (mandatory before pushing):

1. **Rebuild + restart:**
   ```bash
   bin/cli app rebuild
   bin/cli app restart
   bin/cli mail start
   ```

2. **MCP endpoint smoke test (new agent flow):**
   ```bash
   # Expect error -32001 (no header)
   curl -s https://catalyst.workeverywhere.docker/mcp \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $MCP_API_KEY" \
     -d '{"jsonrpc":"2.0","id":"1","method":"tools/list"}' \
     | python3 -m json.tool

   # Expect success (with header)
   curl -s https://catalyst.workeverywhere.docker/mcp \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $MCP_API_KEY" \
     -H "X-Agent-Identifier: jack" \
     -d '{"jsonrpc":"2.0","id":"2","method":"tools/list"}' \
     | python3 -m json.tool

   # Expect error -32001 (unknown slug)
   curl -s https://catalyst.workeverywhere.docker/mcp \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $MCP_API_KEY" \
     -H "X-Agent-Identifier: ghost" \
     -d '{"jsonrpc":"2.0","id":"3","method":"tools/list"}' \
     | python3 -m json.tool
   ```

3. **End-to-end attribution test** — call `create_journal_entry` as Marée via curl (`-H "X-Agent-Identifier: maree"`), then query the DB:
   ```bash
   bin/cli app connect
   bin/rails runner 'puts JournalEntry.last.author.email'  # expect "maree@system.local"
   ```

4. **Browser sweep** (per AGENTS.md §5) — agent-browser against `https://catalyst.workeverywhere.docker/`:
   - [ ] Home page renders (logged out + logged in).
   - [ ] Create account + email verification flow works.
   - [ ] Users CRUD pages render.
   - [ ] Account page renders.
   - [ ] Login page renders.
   - [ ] Dark mode toggle works.
   - [ ] No runtime errors.

   (MCP changes have no direct UI impact, but the runtime suite catches unrelated regressions.)

5. **Mailcatcher sweep** — after a curl-driven `create_journal_entry`, confirm no Jack/Marée auto-subscription email is sent (the `subscribe_trip_members` filter should exclude system actors). Check `https://mail.workeverywhere.docker/`.

---

## 11. Deployment Plan

Phase 1 introduces a **required** HTTP header. Existing Claude Desktop configs that don't send it will break on the next request. Coordinate deploy and config update:

1. **Before merge** — ensure Claude Desktop configs for every agent are prepared:
   ```json
   {
     "mcpServers": {
       "trip-journal": {
         "url": "https://catalyst.workeverywhere.app/mcp",
         "headers": {
           "Authorization": "Bearer your-mcp-api-key",
           "X-Agent-Identifier": "jack"
         }
       }
     }
   }
   ```
   Marée's config sends `"X-Agent-Identifier": "maree"`. Save updated JSON locally but don't swap in yet.

2. **Merge PR** — Kamal deploy kicks off. Migrations run automatically as part of the deploy (`bin/cli db migrate prod` on prod env, per project convention).

3. **Within the same deploy window**, swap Claude Desktop configs to the new header versions on every machine running an agent. Restart Claude Desktop so it picks up the new config.

4. **Verify in production** — run one `tools/list` call per agent slug from each machine to confirm connectivity, then one actual tool invocation (e.g. `get_trip_status`) to confirm attribution.

No `.kamal/secrets` or `config/deploy.yml` changes are required — `MCP_API_KEY` is unchanged. No new secrets.

**Escape hatch (not recommended but documented):** If the coordinated swap is risky, add a `DEFAULT_AGENT_SLUG` ENV var read by the controller when `X-Agent-Identifier` is missing:

```ruby
def agent_slug
  @agent_slug ||=
    request.headers["X-Agent-Identifier"].presence ||
    ENV.fetch("DEFAULT_AGENT_SLUG", "")
end
```

Set `DEFAULT_AGENT_SLUG=jack` in prod for a transition window, then unset + redeploy once configs are updated. **This is a crutch**, not the end state — remove the ENV branch before closing Phase 1.

---

## 12. Documentation Updates

Files edited in step 19-23 of the task list:

| File | Change |
|------|--------|
| `docs/mcp-curl-cheatsheet.md` | Add `X-Agent-Identifier` header to every curl example; drop `actor_type`/`actor_id` note in `create_journal_entry` section (L145) |
| `app/mcp/README.md` | Rewrite API Key Scope (L40-48); update architecture ASCII (L22-26); add agent-identification flow section |
| `AGENTS.md` | Rewrite MCP API Key Scope section (L116) — describe two-layer auth model |
| `README.md` | Update L237 — not just Jack, but any registered agent |
| `.claude/skills/trip-journal-mcp/SKILL.md` | Match README.md / AGENTS.md tone (L40) |

**Left alone:**
- `docs/mcp-architecture.excalidraw` — diagram rework is more effort than value for a v1. Flag as low-priority followup.
- `prompts/Phase N*.md` historical docs — append-only audit trail, don't rewrite history.

---

## 13. Rollback Plan

If production breaks after deploy:

1. **Fast path (roll back code):** `kamal rollback` reverts to the previous container. `agents` table remains populated but unused — harmless. Claude Desktop configs with `X-Agent-Identifier` still work because the old controller ignores unknown headers. No data loss.

2. **Slow path (revert migrations):** Only if agent table itself is causing issues (unlikely — it's additive):
   ```bash
   bundle exec rails db:rollback STEP=2  # drop agents table + backfill
   ```
   Then revert the code.

3. **Data migration is reversible** — `down` drops the Jack agent row. The `jack@system.local` user is untouched.

---

## 14. Future Work (Phases 2 and 3)

Documented here as non-commitments so Phase 1 decisions don't leak Phase-2/3 assumptions.

**Phase 2 — per-trip pairing keys (separate PRP).** Shape the new `agent_trip_grants` table as `(agent_id, trip_id, token_digest, scopes, issued_at, revoked_at, last_used_at)` so Phase 3 OAuth issues the same row via a consent flow. Phase 2 also introduces:
- Key-generation UI on the trip page ("Generate pairing key for <Agent>").
- Trip-scoped authorisation in tool calls (if no grant for this agent/trip pair → JSON-RPC error with a readable "not paired" message).
- Shared `MCP_API_KEY` remains as channel auth; trip keys authorise the trip.
- Default access for unpaired agent + unspecified trip: **nothing** (per decision — prevents data leakage, forces explicit pairing).

**Phase 3 — OAuth.** Replaces manual trip-key issuance with consent flow + dynamic client registration. If Phase 2's grant table is shaped right, this is "swap the issuance mechanism" rather than a rewrite.

**Admin UI.** A Phlex-based `Admin::AgentsController` becomes worthwhile in Phase 2 when trip keys need to be generated/revoked. Phase 1 uses Rails console.

**Drop `journal_entries.actor_type` / `actor_id` columns.** Once Phase 1 has been in production long enough to be confident no reader depends on them.

---

## 15. Reference Documentation

### Project patterns (in-repo)

- `app/actions/CLAUDE.md` — Actions + Dry::Monads pattern (loaded into context when touching `app/actions/**`)
- `AGENTS.md` — full project governance, CLI, PR review rules
- `app/mcp/README.md` — current MCP surface

### Ruby / Rails

- Rails 8.1 guides: https://guides.rubyonrails.org/
- Rails 8.1 Active Record associations: https://guides.rubyonrails.org/association_basics.html
- Rails 8.1 Active Record validations: https://guides.rubyonrails.org/active_record_validations.html
- Dry::Monads documentation: https://dry-rb.org/gems/dry-monads/
- RSpec-rails: https://rspec.info/documentation/latest/rspec-rails/
- FactoryBot: https://thoughtbot.github.io/factory_bot/

### MCP

- MCP specification: https://modelcontextprotocol.io/specification
- MCP Ruby SDK: https://github.com/modelcontextprotocol/ruby-sdk
- Claude Desktop MCP config (custom headers): https://modelcontextprotocol.io/quickstart/user
- Streamable HTTP transport: https://modelcontextprotocol.io/specification/2025-03-26/basic/transports

### JSON-RPC

- JSON-RPC 2.0 specification: https://www.jsonrpc.org/specification
- Custom error codes range (−32000 to −32099): https://www.jsonrpc.org/specification#error_object

### Ruby documentation (from project CLAUDE.md)

- Ruby 4.0: https://docs.ruby-lang.org/en/4.0/
- Ruby on Rails API 7.0: https://api.rubyonrails.org/v7.0/

---

## 16. Skill Self-Evaluation

**Skill used:** `generate-prp`

**Step audit:**
- All steps in the skill's research process were followed: codebase analysis (23 files read), existing-PRP style reference (trip-journal.md, mobile-notification-badge.md, comment-notification-full-email.md), test pattern discovery, documentation inventory.
- External research step was light: MCP gem + spec URLs were already in the system prompt / project docs, so no WebFetch was spent. Rails 8.1 and Dry::Monads URLs are canonical.
- No step was skipped. No step produced unused output.
- `PRPs/templates/` does not exist in this repo — existing PRPs serve as the implicit template. This is fine but the skill's instruction to "use PRPs/templates/prp_base.md" should be softened to "use PRPs/templates/prp_base.md if it exists, otherwise mirror the newest PRP in PRPs/".

**Improvement suggestion:** The skill's "Validation Gates" section references "github-workflow and runtime-test" project skills, but those skills are not named in the user-invocable skill list — the validation gates are actually defined in `AGENTS.md` §3 and §5 (`bundle exec rake project:lint`, `project:tests`, `project:system-tests` + the runtime checklist). Updating the skill to reference `AGENTS.md` directly, or making the github-workflow / runtime-test skills discoverable, would prevent the one-beat confusion when picking executable validation gates.

---

## Confidence Score Justification

**8/10**. Everything is mapped: every file touched is listed with line numbers, every decision has an explicit rationale, pseudocode shows the end state, task list is atomic and ordered, tests cover all five controller branches and all three write-path tools, runtime checklist is concrete, rollback path is two-step. The only residual risk is the coordinated deploy (code + Claude Desktop configs must land together), which is an operational constraint rather than a code one — the escape-hatch `DEFAULT_AGENT_SLUG` is documented if the operator wants belt-and-braces. An AI agent executing this PRP should finish in one pass with green CI on first push.
