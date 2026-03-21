# PRP: Trip Journal Web App - V1 Implementation Plan

**Status:** Draft
**Date:** 2026-03-21
**Confidence Score:** 7/10 (complexity is high; multiple new gems and domain models, but the foundation is solid and patterns are established)

---

## Table of Contents

1. [Repository Audit Snapshot](#1-repository-audit-snapshot)
2. [Assumptions and Open Questions](#2-assumptions-and-open-questions)
3. [Proposed Data Model](#3-proposed-data-model)
4. [Role and Permission Matrix](#4-role-and-permission-matrix)
5. [Trip State Machine](#5-trip-state-machine-and-allowed-transitions)
6. [Actions / Events / Subscribers / Jobs Inventory](#6-actions--events--subscribers--jobs-inventory)
7. [MCP Server Boundary and Capability Surface](#7-mcp-server-boundary-and-capability-surface)
8. [PWA Scope](#8-pwa-scope)
9. [Export Architecture](#9-export-architecture)
10. [Testing Strategy](#10-testing-strategy)
11. [Sequencing, Risks, and Definition of Done per Phase](#11-sequencing-risks-and-definition-of-done-per-phase)
12. [Implementation Tasks](#12-implementation-tasks)
13. [Validation Gates](#13-validation-gates)
14. [Reference Documentation](#14-reference-documentation)

---

## 1. Repository Audit Snapshot

### Confirmed from Repo

| Area | Status | Evidence |
|------|--------|----------|
| **Rails version** | 8.1.2 (`~> 8.1.1` in Gemfile, 8.1.2 in Gemfile.lock) | `Gemfile:8`, `Gemfile.lock` |
| **Ruby version** | 4.0.1 | `.ruby-version`, `Gemfile:5` |
| **SQLite with UUIDs** | Yes, via `sqlite_crypto` gem (custom fork) | `Gemfile:15`, `db/schema.rb` - all tables use `id: uuid` |
| **Propshaft** | 1.3.1 installed | `Gemfile:11` |
| **Importmap** | 2.2.3 installed, pins for Hotwire | `config/importmap.rb` |
| **Turbo Rails** | Installed | `Gemfile:24` |
| **Stimulus Rails** | Installed with controllers | `Gemfile:27`, `app/javascript/controllers/` (theme, toast, hello) |
| **Tailwind CSS** | Installed with dark mode ("class"), custom design tokens | `Gemfile:30-32`, `config/tailwind.config.js`, `app/assets/tailwind/application.css` |
| **Rodauth** | Full setup: create_account, verify_account, login, logout, email_auth, webauthn, webauthn_login | `app/misc/rodauth_main.rb`, `config/initializers/rodauth.rb` |
| **WebAuthn/Passkeys** | Configured: `webauthn` gem, tables created, RP config via ENV | `Gemfile:38`, `db/schema.rb:26-37` |
| **Action Policy** | 0.7.6 installed, `ApplicationPolicy` + `UserPolicy` exist | `Gemfile:41`, `app/policies/` |
| **Phlex** | 2.4.0, 30+ components, full Phlex-first architecture | `Gemfile:44`, `app/components/`, `app/views/` |
| **Solid Queue** | Configured (production: 3 threads, dispatcher) | `Gemfile:55`, `config/queue.yml` |
| **Solid Cache** | Configured (256MB max, in-process dev) | `Gemfile:54`, `config/cache.yml` |
| **Solid Cable** | Configured (async dev, solid_cable prod) | `Gemfile:53`, `config/cable.yml` |
| **Kamal** | 2.11.0, deploy.yml targets workeverywhere.app | `Gemfile:61`, `config/deploy.yml` |
| **Thruster** | Installed, used in Dockerfile CMD | `Gemfile:64`, `Dockerfile` |
| **Active Storage** | Engine loaded, `image_processing` gem present, disk service only | `config/application.rb:8`, `Gemfile:67`, `config/storage.yml` |
| **MCP gem** | 0.8.0 installed (in Gemfile.lock, not direct Gemfile dep) | `Gemfile.lock` |
| **Roleable concern** | Bit-masked roles: `[:superadmin, :admin, :member, :contributor, :guest]` | `app/models/concerns/roleable.rb`, `config/initializers/roles.rb` |
| **User model** | UUID PK, email (unique), name, roles_mask, status | `app/models/user.rb`, `db/schema.rb:39-47` |
| **PWA scaffolding** | Manifest + service worker exist but routes COMMENTED OUT | `app/views/pwa/manifest.json.erb`, `config/routes.rb:12-13` |
| **RSpec** | Full setup: factories, auth helpers, system tests, request specs | `spec/`, `Gemfile:129` |
| **Factory Bot** | User factory with `:admin` trait | `spec/factories/users.rb` |
| **Overcommit** | Configured for pre-commit (RuboCop, whitespace) and commit-msg | `.overcommit.yml` |
| **Docker** | Multi-stage production Dockerfile, bin/cli orchestration | `dockerfiles/`, `bin/cli` |
| **CI** | GitHub Actions: lint, security, tests, system tests | `.github/workflows/ci.yml` |

### Missing / Not Yet Present

| Area | Status | Notes |
|------|--------|-------|
| **Lexxy** | NOT in Gemfile | Must be added. Editor for Action Text. |
| **Action Text** | Engine loaded but NOT set up | No `action_text_rich_texts` table, no `has_rich_text` usage |
| **Dry::Monads** | NOT in Gemfile | Must be added for Actions pattern |
| **Gepub** | NOT in Gemfile | Must be added for ePub export |
| **SeaweedFS / S3 storage** | NOT configured | `config/storage.yml` only has disk + commented S3/GCS |
| **Events infrastructure** | NONE | No `Rails.event` usage, no subscribers, no structured events |
| **Workflows / Job continuations** | NONE | Only `ApplicationJob` base class exists |
| **Trip model** | NONE | No trip-related code |
| **Journal Entry model** | NONE | No journal-related code |
| **Checklist models** | NONE | No checklist-related code |
| **Comment model** | NONE | |
| **Reaction model** | NONE | |
| **AccessRequest model** | NONE | |
| **Invitation model** | NONE | |
| **TripMembership model** | NONE | |
| **MCP server implementation** | NONE | Gem present but no server code |
| **Push notifications** | NONE | Service worker has commented-out example only |
| **Export system** | NONE | No export-related code |

### Assumptions Needing Verification

| Assumption | Risk | Resolution |
|------------|------|------------|
| `sqlite_crypto` supports JSON columns (not JSONB) | Low - SQLite uses `json` natively | Verify with test migration |
| Rodauth can coexist with custom AccessRequest/Invitation flows | Medium | May need custom Rodauth features or bypass |
| `mcp` gem 0.8.0 supports the MCP server pattern needed for Jack | Medium | Check gem docs / add explicit `mcp` to Gemfile |
| Lexxy works with importmap (no npm) | High | Check Lexxy installation guide - may need vendored JS |
| Rails 8.1.2 `Rails.event` API is stable | Low | Confirmed in release notes |
| Active Job Continuations available in 8.1.2 | Low | Confirmed in release notes |

---

## 2. Assumptions and Open Questions

### Assumptions

1. **Super Admin = `superadmin` role** in the existing Roleable concern. The brief's "Super Admin" maps directly to the `:superadmin` bit.
2. **Contributor = `contributor` role**, already in the roles config.
3. **Viewer** = new role. Must add `:viewer` to `config/initializers/roles.rb`. Currently the roles list is `[:superadmin, :admin, :member, :contributor, :guest]`. The `:member` and `:guest` roles will be re-evaluated. Proposed change: `[:superadmin, :admin, :contributor, :viewer, :guest]`. The `:admin` role may be retained for future use or removed to avoid confusion. **Decision needed.**
4. **Jack (AI assistant)** operates as a special system actor, not a regular User. Jack's actions are attributed via `actor_type` / `actor_id` fields rather than requiring a User account.
5. **Telegram is the only AI messaging ingress for V1.** No multi-channel routing.
6. **Active trip context for Jack** will be resolved via an explicit `active_trip_id` on the MCP session or a simple lookup (e.g., the single trip in `started` state).

### Open Questions

1. **Role cleanup:** Should `:admin` and `:member` roles be kept, removed, or aliased? The brief specifies only Super Admin, Contributor, and Viewer. Keeping unused roles creates confusion. **Recommendation:** Rename to `[:superadmin, :contributor, :viewer, :guest]` and migrate existing data.

2. **Notification delivery mechanism for V1:** Email only, or also in-app via Action Cable? The brief mentions push notifications under PWA scope but doesn't specify in-app notifications. **Recommendation:** Email notifications for V1 access/onboarding flows; plan Action Cable channels for real-time updates but defer push notifications.

3. **SeaweedFS readiness:** Is SeaweedFS already provisioned, or should V1 development use local disk storage with S3 config prepared for production switchover? **Recommendation:** Develop with disk storage, configure S3-compatible service definition for SeaweedFS in `config/storage.yml` with ENV-based switching.

4. **Lexxy importmap compatibility:** Lexxy is built on Meta's Lexical framework. Need to verify it ships an ESM build compatible with importmap or if it requires vendoring. **Action:** Check https://basecamp.github.io/lexxy/installation.html before Phase 5.

---

## 3. Proposed Data Model

### Entity Relationship Overview

```
User (existing, modify)
  |-- has_many :trip_memberships
  |-- has_many :trips, through: :trip_memberships
  |-- has_many :journal_entries (as author)
  |-- has_many :comments
  |-- has_many :reactions
  |-- has_many :access_requests (submitter)
  |-- has_many :invitations (inviter = superadmin)

AccessRequest
  |-- belongs_to :user (nullable, pre-signup)

Invitation
  |-- belongs_to :inviter (User, superadmin)
  |-- belongs_to :invitee (User, nullable until signup)

Trip
  |-- has_many :trip_memberships
  |-- has_many :users, through: :trip_memberships
  |-- has_many :journal_entries
  |-- has_many :checklists
  |-- has_many :reactions (polymorphic)

TripMembership
  |-- belongs_to :trip
  |-- belongs_to :user
  |-- role enum: [:contributor, :viewer]

JournalEntry
  |-- belongs_to :trip
  |-- belongs_to :author (User)
  |-- has_rich_text :body (Action Text)
  |-- has_many_attached :images (Active Storage)
  |-- has_many :comments
  |-- has_many :reactions (polymorphic)

Comment
  |-- belongs_to :journal_entry
  |-- belongs_to :user

Reaction (polymorphic)
  |-- belongs_to :reactable (Trip | JournalEntry | Comment)
  |-- belongs_to :user

Checklist
  |-- belongs_to :trip
  |-- has_many :checklist_sections

ChecklistSection
  |-- belongs_to :checklist
  |-- has_many :checklist_items

ChecklistItem
  |-- belongs_to :checklist_section
```

### Table Definitions

#### `access_requests`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | uuid | PK | |
| email | string | NOT NULL, index | Submitter email |
| status | integer | NOT NULL, default: 0 | enum: pending(0), approved(1), rejected(2) |
| reviewed_by_id | uuid | FK(users), nullable | Super admin who reviewed |
| reviewed_at | datetime | nullable | |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

#### `invitations`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | uuid | PK | |
| inviter_id | uuid | FK(users), NOT NULL | Super admin |
| email | string | NOT NULL | Invitee email |
| token | string | NOT NULL, unique | Secure token for invite link |
| status | integer | NOT NULL, default: 0 | enum: pending(0), accepted(1), expired(2) |
| accepted_at | datetime | nullable | |
| expires_at | datetime | NOT NULL | |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

#### `trips`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | uuid | PK | |
| name | string | NOT NULL | |
| description | text | nullable | |
| state | integer | NOT NULL, default: 0 | enum: planning(0), started(1), cancelled(2), finished(3), archived(4) |
| metadata | json | NOT NULL, default: '{}' | Explicitly JSON, NOT JSONB |
| start_date | date | nullable | Explicit start, overrides derived |
| end_date | date | nullable | Explicit end, overrides derived |
| created_by_id | uuid | FK(users), NOT NULL | Super admin who created |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

#### `trip_memberships`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | uuid | PK | |
| trip_id | uuid | FK(trips), NOT NULL | |
| user_id | uuid | FK(users), NOT NULL | |
| role | integer | NOT NULL, default: 1 | enum: contributor(0), viewer(1) |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |
| | | unique: [trip_id, user_id] | |

#### `journal_entries`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | uuid | PK | |
| trip_id | uuid | FK(trips), NOT NULL | |
| author_id | uuid | FK(users), NOT NULL | Human author on whose behalf entry was made |
| name | string | NOT NULL | Entry title |
| description | text | nullable | Short summary |
| entry_date | date | NOT NULL | Canonical date for chronological ordering |
| location_name | string | nullable | Human-readable location |
| latitude | decimal(10,7) | nullable | |
| longitude | decimal(10,7) | nullable | |
| actor_type | string | nullable | 'User' or 'Jack' for attribution |
| actor_id | string | nullable | User UUID or 'jack' |
| telegram_message_id | string | nullable, index | Idempotency key for Telegram |
| telegram_chat_id | string | nullable | For audit/context |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |
| | | index: [trip_id, entry_date, created_at, id] | Canonical ordering index |
| | | unique: [trip_id, telegram_message_id] where telegram_message_id IS NOT NULL | Idempotency constraint |

**Note:** Rich text body via Action Text (`has_rich_text :body`). Images via Active Storage (`has_many_attached :images`).

#### `comments`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | uuid | PK | |
| journal_entry_id | uuid | FK(journal_entries), NOT NULL | |
| user_id | uuid | FK(users), NOT NULL | |
| body | text | NOT NULL | Plain text for V1 |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

#### `reactions`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | uuid | PK | |
| reactable_type | string | NOT NULL | Polymorphic: Trip, JournalEntry, Comment |
| reactable_id | uuid | NOT NULL | |
| user_id | uuid | FK(users), NOT NULL | |
| emoji | string | NOT NULL | Unicode emoji |
| created_at | datetime | NOT NULL | |
| | | unique: [reactable_type, reactable_id, user_id, emoji] | One reaction per emoji per user |

#### `checklists`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | uuid | PK | |
| trip_id | uuid | FK(trips), NOT NULL | |
| name | string | NOT NULL | |
| position | integer | NOT NULL, default: 0 | Sort order |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

#### `checklist_sections`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | uuid | PK | |
| checklist_id | uuid | FK(checklists), NOT NULL | |
| name | string | NOT NULL | |
| position | integer | NOT NULL, default: 0 | |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

#### `checklist_items`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | uuid | PK | |
| checklist_section_id | uuid | FK(checklist_sections), NOT NULL | |
| content | string | NOT NULL | |
| completed | boolean | NOT NULL, default: false | |
| position | integer | NOT NULL, default: 0 | |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

### Modifications to Existing Tables

#### `users` - Add fields

| Column | Type | Notes |
|--------|------|-------|
| No schema changes | | Roles handled by existing `roles_mask`. Update `config/initializers/roles.rb` to: `[:superadmin, :contributor, :viewer, :guest]` |

**Important:** If removing `:admin` and `:member`, must recalculate `roles_mask` values for existing users. The bit positions change when roles are reordered. **Safest approach:** Keep the roles list, add `:viewer` at end, and map Super Admin = `:superadmin`, Contributor = `:contributor`, Viewer = `:viewer`. This avoids breaking existing bit masks.

**Recommended roles list:** `[:superadmin, :admin, :member, :contributor, :viewer, :guest]`

This preserves backward compatibility. `:admin` and `:member` bits remain but are unused in V1 policies.

---

## 4. Role and Permission Matrix

### Global Roles (via `roles_mask` on User)

| Role | Scope | Description |
|------|-------|-------------|
| `superadmin` | Global | Full system access. Creates trips, manages users, reviews access requests, sends invitations. |
| `contributor` | Trip-scoped (via TripMembership) | Can view and write within assigned trips. |
| `viewer` | Trip-scoped (via TripMembership) | Read-only access to assigned trips. |
| `guest` | Default | No trip access. Assigned after signup, before trip assignment. |

### Resource Permission Matrix

| Resource | Action | Super Admin | Contributor | Viewer | Guest |
|----------|--------|:-----------:|:-----------:|:------:|:-----:|
| **AccessRequest** | create (public) | - | - | - | N/A (unauthenticated) |
| **AccessRequest** | index/review | Y | - | - | - |
| **Invitation** | create/send | Y | - | - | - |
| **User** | index/show | Y | - | - | - |
| **User** | create/update/destroy | Y | - | - | - |
| **Trip** | create | Y | - | - | - |
| **Trip** | index (own) | Y | Y | Y | - |
| **Trip** | show | Y | Y (member) | Y (member) | - |
| **Trip** | update | Y | Y (member) | - | - |
| **Trip** | destroy | Y | - | - | - |
| **JournalEntry** | index/show | Y | Y (member) | Y (member) | - |
| **JournalEntry** | create | Y | Y (member) | - | - |
| **JournalEntry** | update | Y | Y (author) | - | - |
| **JournalEntry** | destroy | Y | Y (author) | - | - |
| **Comment** | index/show | Y | Y (member) | Y (member) | - |
| **Comment** | create | Y | Y (member) | Y (member) | - |
| **Comment** | update/destroy | Y | Y (own) | Y (own) | - |
| **Reaction** | create/destroy | Y | Y (member) | Y (member) | - |
| **Checklist** | index/show | Y | Y (member) | Y (member) | - |
| **Checklist** | create/update/destroy | Y | Y (member) | - | - |
| **ChecklistItem** | toggle | Y | Y (member) | - | - |
| **Export** | create | Y | Y (member) | Y (member) | - |

### Policy Implementation Pattern

Follow the existing pattern in `app/policies/`:

```ruby
# app/policies/trip_policy.rb
class TripPolicy < ApplicationPolicy
  def show?
    superadmin? || trip_member?
  end

  def update?
    superadmin? || trip_contributor?
  end

  def create?
    superadmin?
  end

  def destroy?
    superadmin?
  end

  private

  def superadmin?
    user&.role?(:superadmin)
  end

  def trip_member?
    record.trip_memberships.exists?(user_id: user&.id)
  end

  def trip_contributor?
    record.trip_memberships.exists?(user_id: user&.id, role: :contributor)
  end
end
```

### Controller Authorization Pattern

Follow existing pattern from `app/controllers/users_controller.rb`:

```ruby
class TripsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip, only: %i[show edit update destroy]
  before_action :authorize_trip!

  private

  def authorize_trip!
    authorize!(@trip || Trip)
  end
end
```

---

## 5. Trip State Machine and Allowed Transitions

### States

```
planning --> started --> finished --> archived
    |           |
    +---> cancelled <---+
```

### Transition Table

| From | To | Guard Conditions |
|------|----|-----------------|
| `planning` | `started` | At least one trip membership exists |
| `planning` | `cancelled` | None |
| `started` | `finished` | None |
| `started` | `cancelled` | None |
| `finished` | `archived` | None |
| `cancelled` | `planning` | Re-open allowed |

### Invalid Transitions

- `finished` -> `started` (no going back)
- `archived` -> any (terminal state)
- `cancelled` -> `started` (must go through `planning` first)
- `cancelled` -> `finished`
- `cancelled` -> `archived`

### Behavior by State

| State | Journal Entries | Checklists | Comments/Reactions |
|-------|:-:|:-:|:-:|
| `planning` | Create/Edit/Delete | Full CRUD | Full |
| `started` | Create/Edit/Delete | Full CRUD | Full |
| `cancelled` | Read-only | Read-only | Read-only |
| `finished` | Read-only | Read-only | Full (comments/reactions still allowed) |
| `archived` | Read-only | Read-only | Read-only |

### Implementation

Use a simple state machine via an enum with validation:

```ruby
# app/models/trip.rb
class Trip < ApplicationRecord
  VALID_TRANSITIONS = {
    planning: %i[started cancelled],
    started: %i[finished cancelled],
    finished: %i[archived],
    cancelled: %i[planning],
    archived: []
  }.freeze

  enum :state, { planning: 0, started: 1, cancelled: 2, finished: 3, archived: 4 }

  def transition_to!(new_state)
    new_state = new_state.to_sym
    unless VALID_TRANSITIONS[state.to_sym]&.include?(new_state)
      raise InvalidTransitionError, "Cannot transition from #{state} to #{new_state}"
    end
    update!(state: new_state)
  end
end
```

---

## 6. Actions / Events / Subscribers / Jobs Inventory

### Architecture

```
Controller -> Action (Dry::Monads) -> Rails.event.notify -> Subscriber -> Workflow Job
```

### Gem Setup Required

Add to Gemfile:
```ruby
gem "dry-monads", "~> 1.6"
```

### Action Pattern

```ruby
# app/actions/base_action.rb
class BaseAction
  include Dry::Monads[:result, :do]
end

# app/actions/trips/create.rb
module Trips
  class Create < BaseAction
    def call(params:, user:)
      trip = yield validate(params)
      trip = yield persist(trip, user)
      yield emit_event(trip, user)
      Success(trip)
    end

    private

    def validate(params)
      # validation logic
      Success(params)
    end

    def persist(params, user)
      trip = Trip.create!(params.merge(created_by: user))
      Success(trip)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(trip, user)
      Rails.event.notify("trip.created", trip_id: trip.id, user_id: user.id)
      Success()
    end
  end
end
```

### Controller Integration Pattern

```ruby
def create
  result = Trips::Create.new.call(params: trip_params, user: current_user)
  case result
  in Success(trip)
    redirect_to trip, notice: "Trip created."
  in Failure(errors)
    @trip = Trip.new(trip_params)
    @trip.errors.merge!(errors) if errors.respond_to?(:each)
    render Views::Trips::New.new(trip: @trip), status: :unprocessable_content
  end
end
```

### Core Actions Inventory

| Action | Events Emitted | Description |
|--------|---------------|-------------|
| `AccessRequests::Submit` | `access_request.submitted` | Public form submission |
| `AccessRequests::Review` | `access_request.approved` / `access_request.rejected` | Super admin reviews |
| `Invitations::Send` | `invitation.sent` | Super admin sends invite |
| `Invitations::Accept` | `invitation.accepted` | User accepts invite, creates account |
| `Trips::Create` | `trip.created` | Super admin creates trip |
| `Trips::Update` | `trip.updated` | Update trip details |
| `Trips::TransitionState` | `trip.state_changed` | State machine transition |
| `TripMemberships::Assign` | `trip_membership.created` | Assign user to trip |
| `TripMemberships::Remove` | `trip_membership.removed` | Remove user from trip |
| `JournalEntries::Create` | `journal_entry.created` | Create entry (human or Jack) |
| `JournalEntries::Update` | `journal_entry.updated` | Update entry |
| `JournalEntries::Delete` | `journal_entry.deleted` | Delete entry |
| `Comments::Create` | `comment.created` | Add comment |
| `Comments::Delete` | `comment.deleted` | Remove comment |
| `Reactions::Toggle` | `reaction.created` / `reaction.removed` | Add/remove reaction |
| `Checklists::Create` | `checklist.created` | Create checklist |
| `ChecklistItems::Toggle` | `checklist_item.toggled` | Toggle item completion |
| `Exports::Generate` | `export.requested` | Start export generation |

### Subscribers

```ruby
# config/initializers/event_subscribers.rb
Rails.event.subscribe("access_request.submitted", AccessRequestSubscriber)
Rails.event.subscribe("invitation.sent", InvitationSubscriber)
Rails.event.subscribe("trip_membership.created", TripMembershipSubscriber)
Rails.event.subscribe("journal_entry.created", JournalEntrySubscriber)
Rails.event.subscribe("export.requested", ExportSubscriber)
```

### Subscriber -> Job Mapping

| Subscriber | Event | Job Triggered |
|------------|-------|--------------|
| `AccessRequestSubscriber` | `access_request.submitted` | `NotifyAdminJob` (email superadmin) |
| `InvitationSubscriber` | `invitation.sent` | `SendInvitationEmailJob` |
| `TripMembershipSubscriber` | `trip_membership.created` | `SendTripAssignmentEmailJob` |
| `JournalEntrySubscriber` | `journal_entry.created` | `ProcessJournalImagesJob` (variant generation) |
| `ExportSubscriber` | `export.requested` | `GenerateExportJob` (continuable, step-based) |

### Rails.event Implementation

**Documentation:** https://guides.rubyonrails.org/8_1_release_notes.html

```ruby
# Emitting:
Rails.event.notify("trip.created", trip_id: trip.id, user_id: user.id)

# Subscribing:
class AccessRequestSubscriber < ActiveSupport::StructuredEventSubscriber
  def access_request_submitted(event)
    NotifyAdminJob.perform_later(access_request_id: event.payload[:access_request_id])
  end
end
```

### Active Job Continuations for Export

**Documentation:** https://api.rubyonrails.org/classes/ActiveJob/Continuation.html

```ruby
# app/jobs/workflows/generate_export_job.rb
class GenerateExportJob < ApplicationJob
  include ActiveJob::Continuable

  step :collect_entries
  step :render_content
  step :package_export
  step :notify_user

  private

  def collect_entries
    # Gather journal entries with images
  end

  def render_content
    # Render markdown or ePub content
  end

  def package_export
    # Create final file and attach to export record
  end

  def notify_user
    # Notify user export is ready
  end
end
```

---

## 7. MCP Server Boundary and Capability Surface

### Architecture

```
Telegram -> Jack (AI) -> MCP Client -> Local MCP Server -> Rails Actions
```

The MCP server is a thin adapter layer that:
1. Receives tool calls from Jack
2. Authenticates/authorizes via API key or shared secret
3. Delegates to the same Actions used by controllers
4. Returns structured results

### What Belongs Where

| Layer | Responsibility |
|-------|---------------|
| **Rails app** | All business logic via Actions, policies, models |
| **MCP server** | Tool definitions, request/response mapping, auth, idempotency |

### Jack's V1 Capabilities

| Tool | Action | Notes |
|------|--------|-------|
| `create_journal_entry` | `JournalEntries::Create` | With `actor_type: 'Jack'`, `telegram_message_id` for idempotency |
| `update_journal_entry` | `JournalEntries::Update` | |
| `list_journal_entries` | Read-only query | Paginated, filtered by trip |
| `create_comment` | `Comments::Create` | |
| `add_reaction` | `Reactions::Toggle` | |
| `update_trip` | `Trips::Update` | Name, description, metadata |
| `transition_trip` | `Trips::TransitionState` | Start/finish/cancel |
| `toggle_checklist_item` | `ChecklistItems::Toggle` | |
| `list_checklists` | Read-only query | |
| `get_trip_status` | Read-only query | Current state, dates, member count |

### Idempotency for Telegram

Every MCP tool call from Jack that creates or modifies data MUST include:

```json
{
  "telegram_message_id": "12345",
  "telegram_chat_id": "67890",
  "actor_type": "Jack",
  "actor_id": "jack"
}
```

The `JournalEntries::Create` action checks for existing entries with the same `[trip_id, telegram_message_id]` and returns the existing record if found (idempotent).

### Active Trip Context

For V1, Jack resolves the active trip via one of:
1. Explicit `trip_id` parameter in tool calls
2. Fallback: the single trip in `started` state (if exactly one exists)
3. Error if ambiguous (0 or 2+ started trips without explicit ID)

### MCP Server Implementation

Use the `mcp` gem (already in Gemfile.lock). Define tools in `app/mcp/`:

```ruby
# app/mcp/trip_journal_server.rb
class TripJournalServer
  include MCP::Server

  tool "create_journal_entry" do
    description "Create a journal entry for a trip"
    parameter :trip_id, type: :string, required: false
    parameter :name, type: :string, required: true
    parameter :body, type: :string, required: true
    parameter :entry_date, type: :string, required: true
    parameter :location_name, type: :string
    parameter :telegram_message_id, type: :string, required: true
    parameter :telegram_chat_id, type: :string

    execute do |params|
      result = JournalEntries::Create.new.call(
        params: params.merge(actor_type: "Jack", actor_id: "jack"),
        user: resolve_author
      )
      # Return result
    end
  end
end
```

### Authorization for Jack

Jack operates with contributor-level permissions on the active trip. The MCP server authenticates via a shared secret (ENV var) and resolves the trip author user (the trip creator or a designated "Jack operator" user).

---

## 8. PWA Scope

### V1 In Scope

| Feature | Status | Notes |
|---------|--------|-------|
| **Installability** | Must implement | Uncomment PWA routes, update manifest |
| **Manifest** | Exists, needs update | Update name, colors, icons for Trip Journal branding |
| **Service worker** | Exists, skeleton | Enable basic caching strategy (cache-first for assets) |
| **Mobile-first layout** | Must implement | Responsive Tailwind layout, sidebar collapses on mobile |
| **Push notifications** | Plan only | Service worker has commented example; implement subscription + delivery |

### V1 Explicitly Out of Scope

| Feature | Notes |
|---------|-------|
| Camera access | Not in V1 |
| GPS/location access | Not in V1 |
| Offline editing/caching | Not in V1 |
| Background sync | Not in V1 |

### Implementation Steps

1. Uncomment PWA routes in `config/routes.rb`
2. Update `app/views/pwa/manifest.json.erb` with Trip Journal branding
3. Implement basic service worker with asset caching (no offline content)
4. Add `<link rel="manifest">` to application layout
5. Add meta tags for mobile web app (viewport, theme-color, apple-touch-icon)
6. Plan push notification infrastructure (Web Push API + Solid Queue for delivery)

---

## 9. Export Architecture

### V1 Formats

| Format | Gem | Notes |
|--------|-----|-------|
| **Markdown** | None (string templates) | Obsidian-compatible with YAML frontmatter |
| **ePub** | `gepub` | Must add to Gemfile |

### Content Inclusion Rules

| Include | Exclude |
|---------|---------|
| Trip name, description, dates | Comments |
| Journal entry text (from Action Text) | Reactions |
| Journal entry images (from Active Storage) | Checklists |
| Chronological ordering | User/membership data |

### Markdown Export Structure

```
trip-name/
  _index.md           # Trip frontmatter + description
  2026-03-15-entry-1.md  # Journal entries by date
  2026-03-16-entry-2.md
  assets/
    image-1.jpg        # Extracted from Active Storage
    image-2.png
```

Each journal entry markdown file:

```markdown
---
title: "Entry Name"
date: 2026-03-15
location: "Paris, France"
latitude: 48.8566
longitude: 2.3522
---

# Entry Name

[rich text body converted from Action Text HTML to Markdown]

![Photo description](assets/image-1.jpg)
```

### ePub Export

Use `gepub` gem. **Documentation:** https://github.com/skoji/gepub

```ruby
# app/services/exports/epub_generator.rb
book = GEPUB::Book.new
book.primary_identifier("urn:uuid:#{trip.id}")
book.language = "en"
book.add_title(trip.name)
book.add_creator(trip.created_by.name)

trip.journal_entries.chronological.each do |entry|
  # Convert Action Text to XHTML
  content = ActionText::Content.new(entry.body).to_html
  book.add_item("entry-#{entry.id}.xhtml").add_content(StringIO.new(xhtml_wrap(content)))

  # Add images
  entry.images.each do |image|
    book.add_item("images/#{image.filename}", StringIO.new(image.download))
  end
end
```

### Export Delivery

Exports are generated asynchronously via `GenerateExportJob` (Active Job Continuation). The result is attached to an `Export` model via Active Storage and the user is notified via email when ready.

### Export Model

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK |
| trip_id | uuid | FK(trips) |
| user_id | uuid | FK(users), who requested |
| format | integer | enum: markdown(0), epub(1) |
| status | integer | enum: pending(0), processing(1), completed(2), failed(3) |
| has_one_attached :file | | The generated export file |
| created_at | datetime | |
| updated_at | datetime | |

---

## 10. Testing Strategy

### Test Pyramid

Follow existing patterns found in `spec/`:

| Layer | Location | Tools | What to Test |
|-------|----------|-------|-------------|
| **Model** | `spec/models/` | RSpec, FactoryBot | Validations, associations, scopes, state machine, chronological ordering, derived dates/locations |
| **Action** | `spec/actions/` | RSpec, Dry::Monads matchers | Success/Failure paths, event emission, idempotency |
| **Policy** | `spec/policies/` | RSpec | Every cell in permission matrix, edge cases |
| **Request** | `spec/requests/` | RSpec | HTTP responses, authorization enforcement, params handling |
| **System** | `spec/system/` | RSpec, Capybara | User-facing flows end-to-end |
| **View/Component** | `spec/views/`, `spec/components/` | RSpec, phlex-testing-capybara | Rendering, conditional content |
| **Subscriber** | `spec/subscribers/` | RSpec | Event -> job dispatch |
| **Job/Workflow** | `spec/jobs/` | RSpec | Job execution, continuation steps |
| **Export** | `spec/services/exports/` | RSpec | Content correctness, file generation |
| **MCP** | `spec/mcp/` | RSpec | Tool call -> action mapping, idempotency, auth |

### Existing Test Patterns to Follow

**Request spec pattern** (from `spec/requests/users_spec.rb`):
```ruby
let!(:admin) { create(:user, :admin) }
before { stub_current_user(admin) }

it "renders a successful response" do
  get users_url
  expect(response).to be_successful
end
```

**System test pattern** (from `spec/system/users_spec.rb`):
```ruby
let(:admin) { create(:user, :admin) }
before { login_as(user: admin) }

it "lists users" do
  visit users_path
  expect(page).to have_content("Users")
end
```

**Model spec pattern** (from `spec/models/user_spec.rb`):
```ruby
RSpec.describe User do
  it "defaults new accounts to guest" do
    user = described_class.create!(name: "Guest", email: "g@example.com")
    expect(user.roles).to eq([:guest])
  end
end
```

### Factories to Create

```ruby
# spec/factories/trips.rb
factory :trip do
  name { "My Trip" }
  state { :planning }
  association :created_by, factory: :user

  trait :started do
    state { :started }
  end
end

# spec/factories/trip_memberships.rb
factory :trip_membership do
  association :trip
  association :user
  role { :contributor }

  trait :viewer do
    role { :viewer }
  end
end

# spec/factories/journal_entries.rb
factory :journal_entry do
  association :trip
  association :author, factory: :user
  name { "Day 1 in Paris" }
  entry_date { Date.current }
  location_name { "Paris, France" }
end

# ... etc for all models
```

### Key Test Scenarios

**Chronological ordering:**
- Entries with different `entry_date` sort by date
- Entries with same date sort by `created_at`
- Same date + same created_at sort by `id`
- Retroactive entry reorders timeline

**Derived dates/locations:**
- Trip with no explicit dates derives from entries
- Trip with explicit dates ignores entry dates
- Empty trip returns nil for derived values
- Adding entry before existing entries changes derived start

**State machine:**
- Valid transitions succeed
- Invalid transitions raise errors
- Behavior restrictions by state (read-only in archived)

**Idempotency:**
- Creating entry with same telegram_message_id returns existing
- Different telegram_message_id creates new entry

**Authorization:**
- Every role/resource combination from permission matrix
- Trip-scoped access (member vs non-member)
- Contributor vs viewer distinctions

---

## 11. Sequencing, Risks, and Definition of Done per Phase

### Phase 1: Repository Alignment / Foundational Setup

**Scope:**
- Add gems: `dry-monads`, `gepub`, `lexxy` (if importmap-compatible), explicit `mcp`
- Update `config/initializers/roles.rb` to add `:viewer` role
- Create `BaseAction` class in `app/actions/`
- Set up Rails.event subscriber infrastructure
- Set up Action Text (install migration, configure)
- Configure Active Storage S3-compatible service definition for SeaweedFS (ENV-switched)
- Uncomment and update PWA routes
- Create `app/mcp/` directory structure

**Dependencies:** None (foundational)

**Risks:**
- Lexxy may not work with importmap -> fallback: vendor JS or defer Lexxy to Phase 5
- `sqlite_crypto` may have issues with new column types -> test migration early
- Adding `:viewer` to roles list changes bit positions -> add at end to preserve mask

**Definition of Done:**
- [ ] All new gems install and bundle passes
- [ ] `BaseAction` exists with `Dry::Monads` included
- [ ] Action Text migration runs, `has_rich_text` works on a test model
- [ ] `config/storage.yml` has SeaweedFS service definition (can use disk locally)
- [ ] PWA manifest and service worker routes serve correctly
- [ ] `rails.event` subscriber can be registered and receives test events
- [ ] `bundle exec rake project:tests` passes
- [ ] `bundle exec rake project:lint` passes

---

### Phase 2: Access and Onboarding Flow

**Scope:**
- Create `AccessRequest` model, migration, action, policy, controller, views
- Create `Invitation` model, migration, action, policy, controller, views
- Build public landing page with "Request Access" form
- Build admin access request review UI
- Build invitation sending flow
- Build invitation acceptance flow (hooks into Rodauth create_account)
- Mailer: access request notification, invitation email, post-signup notification

**Dependencies:** Phase 1

**Risks:**
- Integrating invitation acceptance with Rodauth's create_account flow may be tricky
- Need to handle race conditions on invitation tokens

**Definition of Done:**
- [ ] Public visitor can submit access request
- [ ] Super admin receives email notification
- [ ] Super admin can approve/reject requests
- [ ] Super admin can send invitation with secure token
- [ ] Invited user can create account via invitation link
- [ ] Super admin notified after signup
- [ ] All actions emit structured events
- [ ] Policy tests cover all access patterns
- [ ] Request and system tests pass

---

### Phase 3: Core Domain Modeling

**Scope:**
- Create `Trip` model with state machine, metadata JSON, derived dates/locations
- Create `TripMembership` model
- Create `JournalEntry` model with Action Text body, Active Storage images
- Create chronological ordering scope
- Implement derived date/location methods on Trip
- Build Trip CRUD controllers and Phlex views
- Build JournalEntry CRUD within trip context
- Build TripMembership management (super admin assigns users)

**Dependencies:** Phase 2

**Risks:**
- Chronological ordering with retroactive entries is complex
- Derived dates/locations must handle edge cases (no entries, no location data)
- Action Text + Active Storage integration must work correctly with Phlex views

**Definition of Done:**
- [ ] Trip CRUD works with all states
- [ ] State machine enforces valid transitions
- [ ] Journal entries display in canonical chronological order
- [ ] Retroactive entries correctly reorder timeline
- [ ] Derived trip dates and locations calculate correctly
- [ ] Images upload and display via Active Storage
- [ ] Rich text editing works via Action Text (with or without Lexxy)
- [ ] Trip membership assignment works
- [ ] All model validations and scopes tested
- [ ] Request and system tests pass

---

### Phase 4: Authorization and Policy Enforcement

**Scope:**
- Create policies for all resources: Trip, JournalEntry, Comment, Reaction, Checklist, ChecklistItem, AccessRequest, Invitation, Export
- Enforce at controller level with `authorize!`
- Add `verify_authorized` after_action callback
- Trip-scoped authorization (check membership + role)
- State-based restrictions (read-only in cancelled/archived)

**Dependencies:** Phase 3

**Risks:**
- Complex authorization logic (trip membership + role + state)
- Performance: membership lookups on every request -> consider caching

**Definition of Done:**
- [ ] Every controller action is authorized
- [ ] Every cell in the permission matrix has a passing test
- [ ] Unauthorized access returns 403
- [ ] State-based restrictions enforced
- [ ] No authorization bypass possible
- [ ] Policy spec coverage > 95%

---

### Phase 5: Rich Text and Media (Lexxy + Action Text + Active Storage)

**Scope:**
- Install and configure Lexxy (if importmap-compatible, else use Trix default)
- Configure `config.lexxy.override_action_text_defaults = true`
- Integrate rich text editor into journal entry forms
- Configure image upload via Action Text embedded attachments
- Configure Active Storage service for production (SeaweedFS S3-compatible)
- Image variant processing (thumbnails, optimized display sizes)

**Dependencies:** Phase 3

**Risks:**
- **HIGH:** Lexxy importmap compatibility is unverified. Lexical (Meta) is typically bundled.
- Fallback: Use Trix (Action Text default) for V1, plan Lexxy for V2
- Image processing in SQLite/Docker environment may need configuration

**Definition of Done:**
- [ ] Rich text editor renders in journal entry form
- [ ] Images can be embedded in journal entries
- [ ] Images display correctly in journal entry views
- [ ] Image variants generate (thumbnails)
- [ ] Active Storage service works in development (disk) and is configured for production (S3)
- [ ] System test verifies editor and image upload

---

### Phase 6: Comments, Reactions, and Checklists

**Scope:**
- Create Comment model, controller, views (nested under JournalEntry)
- Create Reaction model (polymorphic), controller, views
- Create Checklist, ChecklistSection, ChecklistItem models
- Build checklist CRUD UI with drag-and-drop ordering (Stimulus)
- Implement checklist item toggle (Turbo Stream for real-time updates)
- Wire up emoji reaction picker

**Dependencies:** Phase 4

**Risks:**
- Polymorphic reactions need careful indexing
- Drag-and-drop ordering with Stimulus (importmap only, no Sortable.js unless ESM)
- Position column management

**Definition of Done:**
- [ ] Comments create/display under journal entries
- [ ] Reactions can be toggled on trips, entries, comments
- [ ] Emoji picker works
- [ ] Checklist hierarchy renders correctly
- [ ] Checklist items can be toggled
- [ ] Position ordering works
- [ ] Turbo Streams update UI without full page reload
- [ ] All models have tests
- [ ] System tests for key flows

---

### Phase 7: Eventing and Workflow Orchestration

**Scope:**
- Wire up all Actions to emit structured events
- Implement all Subscribers
- Implement Workflow Jobs (notification emails, image processing, etc.)
- Configure recurring jobs in `config/recurring.yml`
- Implement Active Job Continuation for export generation

**Dependencies:** Phases 1-6

**Risks:**
- Event ordering and idempotency in subscribers
- Job failures and retry logic
- Continuation steps must be independently restartable

**Definition of Done:**
- [ ] Every action emits its documented event
- [ ] Every subscriber dispatches to the correct job
- [ ] Email notifications send for all documented triggers
- [ ] Jobs handle failures gracefully
- [ ] Export generation works end-to-end via continuation
- [ ] Subscriber tests verify event -> job mapping
- [ ] Job tests verify execution logic

---

### Phase 8: PWA / Mobile Capabilities

**Scope:**
- Finalize manifest with proper branding, icons, screenshots
- Implement service worker with cache-first strategy for assets
- Responsive layout for all views (mobile-first Tailwind)
- Add install prompt handling (beforeinstallprompt event)
- Plan push notification subscription (Web Push API)

**Dependencies:** Phase 3 (views must exist)

**Risks:**
- Service worker caching strategy may conflict with Turbo
- Push notification requires VAPID keys and subscription management

**Definition of Done:**
- [ ] App is installable on mobile (Chrome, Safari)
- [ ] All pages are mobile-responsive
- [ ] Service worker caches assets correctly
- [ ] No Turbo conflicts with service worker
- [ ] System test verifies mobile viewport rendering

---

### Phase 9: MCP Integration with Jack

**Scope:**
- Implement MCP server with all tools from capability surface
- Implement authentication (shared secret via ENV)
- Implement idempotency checking for Telegram
- Implement active trip resolution
- Implement actor attribution
- Integration tests for all tools

**Dependencies:** Phases 3-6 (all domain models and actions must exist)

**Risks:**
- MCP gem API may not match expected patterns -> check docs
- Jack's authorization scope needs clear boundaries
- Telegram retry scenarios need thorough testing

**Definition of Done:**
- [ ] All MCP tools callable and return correct results
- [ ] Authentication enforced
- [ ] Idempotency works (duplicate telegram_message_id returns existing)
- [ ] Active trip resolution works correctly
- [ ] Actor attribution recorded on all Jack-created records
- [ ] Integration tests for every tool
- [ ] Error cases handled (no active trip, unauthorized, etc.)

---

### Phase 10: Export Architecture

**Scope:**
- Implement `Export` model and controller
- Implement Markdown export (Obsidian-compatible)
- Implement ePub export via Gepub
- Action Text HTML -> Markdown conversion
- Active Storage image extraction and packaging
- Async generation via GenerateExportJob (continuation)
- Download delivery

**Dependencies:** Phases 3, 5, 7

**Risks:**
- Action Text HTML to Markdown conversion accuracy
- Large image files in ePub may cause memory issues -> stream
- Export job must handle interruption and resume

**Definition of Done:**
- [ ] Markdown export generates correct structure and content
- [ ] ePub export generates valid ePub file
- [ ] Images included in both formats
- [ ] Comments, reactions, checklists excluded
- [ ] Chronological ordering matches app display
- [ ] Export request -> background generation -> download works end-to-end
- [ ] Export tests verify content correctness

---

### Phase 11: Hardening, Testing, Deployment Readiness

**Scope:**
- Full test suite passes (models, actions, policies, requests, system)
- Security audit: Brakeman, bundle-audit clean
- Performance review: N+1 queries (Bullet), slow queries
- Seed data for development
- Docker image builds cleanly
- Kamal deploy config updated for new services/volumes
- Documentation update

**Dependencies:** All previous phases

**Risks:**
- Integration issues between phases discovered late
- Performance problems under load
- Docker volume management for SeaweedFS

**Definition of Done:**
- [ ] `bundle exec rake` (all tests + lint) passes
- [ ] `bundle exec brakeman` clean
- [ ] `bundle exec bundle-audit check` clean
- [ ] Docker image builds successfully
- [ ] `bin/cli app rebuild && bin/cli app restart` works
- [ ] Runtime test checklist passes (all pages render)
- [ ] Kamal deploy succeeds to staging

---

## 12. Implementation Tasks

These tasks should be executed in order, following the GitHub Workflow skill (issue -> kanban -> branch -> implement -> test -> verify -> PR).

### Phase 1: Foundation
1. Add `dry-monads ~> 1.6` and `gepub` to Gemfile, bundle install
2. Add `:viewer` to roles config (append to end of list to preserve bit positions)
3. Create `app/actions/base_action.rb` with `Dry::Monads[:result, :do]`
4. Run `bin/rails action_text:install` to set up Action Text
5. Add SeaweedFS S3 service config to `config/storage.yml` (ENV-switched)
6. Uncomment PWA routes in `config/routes.rb`, update manifest
7. Set up `config/initializers/event_subscribers.rb` skeleton
8. Add `mcp` gem explicitly to Gemfile
9. Verify Lexxy compatibility with importmap (if not compatible, defer to Phase 5 with Trix fallback)

### Phase 2: Access & Onboarding
10. Create AccessRequest migration, model, action, policy, controller, views
11. Create Invitation migration, model, action, policy, controller, views
12. Build public landing page with Request Access form
13. Build admin review UI for access requests
14. Build invitation send and accept flows
15. Integrate invitation acceptance with Rodauth create_account
16. Implement mailers: access request notification, invitation, post-signup

### Phase 3: Core Domain
17. Create Trip migration and model with state machine
18. Create TripMembership migration and model
19. Create JournalEntry migration and model with Action Text, Active Storage
20. Implement chronological ordering scope on JournalEntry
21. Implement derived dates and locations on Trip
22. Build Trip CRUD controller and Phlex views
23. Build JournalEntry CRUD controller and Phlex views (nested under Trip)
24. Build TripMembership management UI

### Phase 4: Authorization
25. Create TripPolicy, JournalEntryPolicy, CommentPolicy, ReactionPolicy
26. Create ChecklistPolicy, AccessRequestPolicy, InvitationPolicy, ExportPolicy
27. Add `verify_authorized` to controllers, enforce trip-scoped authorization
28. Implement state-based restrictions
29. Write comprehensive policy specs

### Phase 5: Rich Text & Media
30. Install and configure Lexxy (or Trix fallback)
31. Integrate rich text editor into JournalEntry forms
32. Configure Active Storage image upload in editor
33. Set up image variant processing

### Phase 6: Social & Checklists
34. Create Comment migration, model, controller, views
35. Create Reaction migration, model (polymorphic), controller, views
36. Create Checklist, ChecklistSection, ChecklistItem migrations and models
37. Build checklist CRUD UI with toggle
38. Wire up Turbo Streams for real-time updates

### Phase 7: Eventing & Workflows
39. Wire Actions to emit structured events via Rails.event
40. Implement Subscribers
41. Implement notification/email jobs
42. Implement GenerateExportJob with Active Job Continuations

### Phase 8: PWA
43. Finalize PWA manifest, service worker, install prompt
44. Ensure all views are mobile-responsive

### Phase 9: MCP
45. Implement MCP server with all tools
46. Implement auth, idempotency, active trip resolution
47. Integration tests for MCP tools

### Phase 10: Export
48. Create Export model and controller
49. Implement Markdown export generator
50. Implement ePub export generator
51. Wire up async generation and download

### Phase 11: Hardening
52. Full test suite pass, security audit, performance review
53. Seed data, Docker build, Kamal config update
54. Runtime test verification

---

## 13. Validation Gates

### Pre-Commit (Every Phase)

```bash
# Ruby version manager activation (run detect.sh first)
eval "$(rbenv init -)" && bundle exec rake project:fix-lint
eval "$(rbenv init -)" && bundle exec rake project:lint
eval "$(rbenv init -)" && bundle exec rake project:tests
eval "$(rbenv init -)" && bundle exec rake project:system-tests
```

### Runtime Test (Before Push)

Follow the `/runtime-test` skill:

```bash
bin/cli app rebuild
bin/cli app restart
bin/cli mail start
```

Then verify with `agent-browser` at `https://catalyst.workeverywhere.docker/`:
- Home page renders (logged out and logged in)
- Auth flows work (create account, verify, sign in, sign out)
- All CRUD pages render
- Trip pages render with correct authorization
- Journal entries display in chronological order
- Rich text editor works
- Dark mode toggle works
- No runtime errors

### GitHub Workflow (Every Task)

Follow the `/github-workflow` skill:
1. Create GitHub issue with detailed plan
2. Add to Kanban board
3. Move through: Backlog -> Ready -> In Progress -> In Review -> Done
4. Branch from main: `feature/<descriptive-name>`
5. All tests + lint pass before commit
6. Runtime test before push
7. Create PR with `Closes #N`

### Security Gates

```bash
eval "$(rbenv init -)" && bundle exec brakeman --no-pager
eval "$(rbenv init -)" && bundle exec bundle-audit check --update
```

---

## 14. Reference Documentation

### Core Rails

| Resource | URL |
|----------|-----|
| Rails 8.1 Release Notes | https://guides.rubyonrails.org/8_1_release_notes.html |
| Rails.event Structured Events | https://api.rubyonrails.org/classes/ActiveSupport/StructuredEventSubscriber.html |
| Active Job Continuations | https://api.rubyonrails.org/classes/ActiveJob/Continuation.html |
| Active Storage Overview | https://guides.rubyonrails.org/active_storage_overview.html |
| Action Text Overview | https://guides.rubyonrails.org/action_text_overview.html |

### Authentication & Authorization

| Resource | URL |
|----------|-----|
| rodauth-rails | https://github.com/janko/rodauth-rails |
| Passkey auth with Rodauth | https://janko.io/passkey-authentication-with-rodauth/ |
| Action Policy docs | https://actionpolicy.evilmartians.io/ |
| Action Policy GitHub | https://github.com/palkan/action_policy |

### View Layer

| Resource | URL |
|----------|-----|
| Phlex docs | https://www.phlex.fun/ |
| phlex-rails GitHub | https://github.com/yippee-fun/phlex-rails |
| Tailwind CSS docs | https://tailwindcss.com/docs |

### Libraries

| Resource | URL |
|----------|-----|
| Dry::Monads v1.6 | https://dry-rb.org/gems/dry-monads/1.6/ |
| Dry::Monads Do notation | https://dry-rb.org/gems/dry-monads/main/do-notation/ |
| Lexxy GitHub | https://github.com/basecamp/lexxy |
| Lexxy docs | https://basecamp.github.io/lexxy/ |
| Lexxy installation | https://basecamp.github.io/lexxy/installation.html |
| Gepub GitHub | https://github.com/skoji/gepub |

### Infrastructure

| Resource | URL |
|----------|-----|
| Solid Queue | https://github.com/rails/solid_queue |
| Solid Cache | https://github.com/rails/solid_cache |
| Solid Cable | https://github.com/rails/solid_cable |
| Kamal docs | https://kamal-deploy.org/docs/installation/ |
| SeaweedFS S3 API | https://github.com/seaweedfs/seaweedfs/wiki/Amazon-S3-API |

### MCP & AI

| Resource | URL |
|----------|-----|
| Agent Skills spec | https://github.com/agentskills/agentskills |
| MCP Protocol | https://modelcontextprotocol.io/ |

### Design Resources (Local)

UI components are available at `~/Workspace/WebUIComponents/`:
- Application shells: `application_ui/application_shells/sidebar/`
- Feeds: `application_ui/lists/feeds/` (for journal timeline)
- Cards: `application_ui/layout/cards/` (for journal entries)
- Forms: `application_ui/forms/` (for entry/checklist forms)
- Detail screens: `application_ui/page_examples/detail_screens/`
- Stacked lists: `application_ui/lists/stacked_lists/` (for checklists)

---

## Quality Checklist

- [x] All necessary context included (codebase audit, existing patterns, file paths)
- [x] Validation gates are executable by AI (rake tasks, runtime test skill, github workflow skill)
- [x] References existing patterns (controllers, policies, factories, test helpers)
- [x] Clear implementation path (11 phases with dependencies, tasks numbered)
- [x] Error handling documented (Dry::Monads Result, state machine guards, idempotency)
- [x] Role/permission matrix comprehensive
- [x] Data model complete with column types and constraints
- [x] External documentation URLs provided for all key technologies
