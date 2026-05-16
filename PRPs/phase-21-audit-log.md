# PRP: Phase 21 — Audit Journal

**Status:** Draft (preparation + implementation blueprint)
**Date:** 2026-05-15
**Type:** Feature — cross-cutting observability (model + event subscriber + async writer + live feed UI)
**Confidence Score:** 8/10 — Every moving part has an exact in-repo precedent: the Notification Center is a 1:1 template for `subscriber → job → ActionCable → Stimulus`, the Feed Wall is the template for the Phlex feed, and all 25 mutations already emit `Rails.event` structured events. The two reasons it is not 9/10: (1) reliable actor capture requires introducing `ActiveSupport::CurrentAttributes` plus additive payload enrichment across ~8 `app/actions/**` files, and (2) the design leans on `Rails.event` dispatching subscribers **synchronously in the request thread** — true in Rails 8.1, but it is the single load-bearing assumption. Scope was deliberately narrowed (superadmin General console, full‑text search, advanced filters, and net‑new auth-event emit points are explicitly Phase 22) to keep this one-pass.

---

## Table of Contents

1. [Clarifying Questions — Resolved](#1-clarifying-questions--resolved)
2. [Problem Statement](#2-problem-statement)
3. [Goals and Non-Goals](#3-goals-and-non-goals)
4. [Event Taxonomy](#4-event-taxonomy)
5. [Event Schema](#5-event-schema)
6. [Permission Matrix](#6-permission-matrix)
7. [UX of the Feed](#7-ux-of-the-feed)
8. [Edge Cases](#8-edge-cases)
9. [Write/Read Characteristics](#9-writeread-characteristics)
10. [Codebase Context](#10-codebase-context)
11. [Data Model](#11-data-model)
12. [Implementation Blueprint](#12-implementation-blueprint)
13. [Task List (ordered)](#13-task-list-ordered)
14. [Testing Strategy](#14-testing-strategy)
15. [Validation Gates (Executable)](#15-validation-gates-executable)
16. [Runtime Test Checklist](#16-runtime-test-checklist)
17. [Google Stitch Prompt](#17-google-stitch-prompt)
18. [Decisions to Push Back to the Team](#18-decisions-to-push-back-to-the-team)
19. [Documentation Updates](#19-documentation-updates)
20. [Rollback Plan](#20-rollback-plan)
21. [Out of Scope / Phase 22](#21-out-of-scope--phase-22)
22. [Reference Documentation](#22-reference-documentation)
23. [Quality Checklist](#23-quality-checklist)
24. [Skill Self-Evaluation](#24-skill-self-evaluation)

---

## 1. Clarifying Questions — Resolved

The brief was ambiguous on four points that change the entire shape of the design. They were put to the product owner and answered before this PRP was finalised:

| # | Ambiguity | Resolution | Consequence |
|---|-----------|------------|-------------|
| Q1 | "Contributors and above" + "General (app-wide)" — who sees what, and does General include auth/security events? The codebase has **two** role systems: user-level `superadmin > contributor > viewer > guest` (`users.roles_mask` bitfield, `config/initializers/roles.rb`) and per-trip `TripMembership.role ∈ {contributor, viewer}`. | **General = superadmin-only security log.** It includes ALL domain events across every trip PLUS app-wide events (access requests, invitations) and — later — auth events. **Trip-specific = contributor-and-above on that trip** (no auth events). | Audit rows must support a **nullable `trip_id`** (app-wide events) and must be **captured for every actor including system/agent**. The General/superadmin console UI is Phase 22; the data model captures everything from day one so the console has history when built. |
| Q2 | "Lower roles can access the Journal, they just cannot see it." | **Hidden entirely.** Nav entry and route are hidden from viewers/guests; direct access **404s**. | Overrides the brief's literal "can access, cannot see". The trip-scoped route returns `404` (not the app-wide `403`) for non-contributors — a deliberate, documented deviation from the global `ActionPolicy::Unauthorized → 403` convention. See [§18](#18-decisions-to-push-back-to-the-team) flag #1. |
| Q3 | Before/after detail per edit. No versioning gem exists. | **Changed fields + values, no gem.** Capture changed attribute names and their before→after values in the Action service layer, store in a JSON `metadata` column, render a compact inline diff. | ~8 `app/actions/**` update/transition/toggle files get an **additive** `changes:`/`actor:` key in their `Rails.event.notify` payload. Rich-text `body` is shown as "body changed" (no HTML diff in Phase 21). |
| Q4 | How much ships in Phase 21. | **Foundation + trip feed + live UI.** `AuditLog` model, `AuditLogSubscriber` wired to all existing `Rails.event` events, trip-scoped feed with live ActionCable updates, Stitch design prompt. | Superadmin General console, full-text search, advanced actor/date filters, and net-new auth-event emit points are **Phase 22**. |

---

## 2. Problem Statement

Catalyst is a collaborative trip-planning app where multiple humans **and** automated actors (MCP agents like `jack`/`maree`, the Telegram bot) mutate shared trip data — journal entries, comments, reactions, checklists, memberships, trip state. Today there is **no durable record of who did what, when**. Every mutation already flows through the `app/actions/**` service layer and emits a structured `Rails.event` (see `config/initializers/event_subscribers.rb`), but the subscribers only `Rails.logger.info` or fan out notifications — **nothing is persisted as an audit trail**. There is no `paper_trail`/`audited`/`logidze` gem and no `created_by`/`updated_by` columns on most models.

Consequences:
- Contributors cannot answer "who changed the trip dates?" or "who deleted that entry?".
- There is no superadmin-level security/activity view spanning trips, access requests, and invitations.
- Agent/automated writes are invisible — a correctness and trust problem as MCP usage grows (Phases 19–20).

The Audit Journal closes this gap: an **append-only, chronological, role-gated feed of every action**, written asynchronously off the request path, and pushed to the UI live without a reload.

---

## 3. Goals and Non-Goals

### Goals (Phase 21)
1. A single `audit_logs` table that durably records every existing `Rails.event` mutation, immutable and readable even after the audited object/user is deleted (denormalised actor + target snapshots).
2. Reliable **actor attribution** for every event — including events whose payload carries no actor today, and including system/agent/Telegram actors (tagged by `source`).
3. A **trip-scoped Activity feed** at `/trips/:trip_id/audit_logs`, visible only to superadmins and trip contributors, grouped by day, with inline edit diffs, live-updating via ActionCable (no reload).
4. Zero added latency to user actions — persistence and broadcast happen in a Solid Queue job.
5. A Google Stitch design prompt for the feed UI.

### Non-Goals (Phase 21 — see [§21](#21-out-of-scope--phase-22))
- Superadmin **General/app-wide console** UI (data is captured; the screen is Phase 22).
- Full-text **search** and advanced **actor/date/action filters** (Phase 22).
- Net-new **auth event emit points** (login/logout/passkey/password) — Rodauth emits none today (Phase 22).
- A versioning gem or full record reconstruction.
- Rich-text/HTML body **diffing** (Phase 21 renders "body changed").
- Retention / GDPR erasure tooling (flagged, Phase 22).

---

## 4. Event Taxonomy

Every action below already emits a `Rails.event` from `app/actions/**` (verified). "Actor in payload today?" matters because it determines the actor-resolution path (see [§12](#12-implementation-blueprint)). "Tier" drives default UI visibility (low-signal hidden behind a toggle).

### Trip lifecycle
| Event (action key) | Emitted today | Actor in payload | trip_id | Tier | Notes |
|---|---|---|---|---|---|
| `trip.created` | ✅ `Trips::Create` | ❌ | ✅ | High | Actor via `Trip.created_by_id` fallback |
| `trip.updated` | ✅ `Trips::Update` | ❌ | ✅ | High | Needs `changes:` enrichment |
| `trip.state_changed` | ✅ `Trips::TransitionState` | ❌ | ✅ | High | `from_state`/`to_state` already in payload |
| `trip.deleted` | ❌ **gap** | ❌ | ✅ | High | **No `Trips::Delete` action exists** — flag #4, new task |

### Membership / roles
| Event | Emitted today | Actor in payload | trip_id | Tier | Notes |
|---|---|---|---|---|---|
| `trip_membership.created` | ✅ `TripMemberships::Assign` | ✅ `actor_id` | ✅ | High | |
| `trip_membership.removed` | ✅ `TripMemberships::Remove` | ❌ (`user_id` = *target*, not actor) | ✅ | High | Actor via `Current` |
| `trip_membership.role_changed` | ❌ no role-change action exists | — | — | High | Flag #5 — Phase 22 if/when added |

### Itinerary (journal entries)
| Event | Emitted today | Actor in payload | trip_id | Tier |
|---|---|---|---|---|
| `journal_entry.created` | ✅ `JournalEntries::Create` | ✅ `actor_id` | ✅ | High |
| `journal_entry.updated` | ✅ `JournalEntries::Update` | ❌ | ✅ | High (needs `changes:`) |
| `journal_entry.deleted` | ✅ `JournalEntries::Delete` | ❌ | ✅ | High |
| `journal_entry.images_added` | ✅ `JournalEntries::AttachImages` | ❌ | ✅ (via entry) | Medium |

### Comments
| Event | Emitted today | Actor in payload | Tier |
|---|---|---|---|
| `comment.created` | ✅ `Comments::Create` | ✅ `actor_id` | High |
| `comment.updated` | ✅ `Comments::Update` | ❌ | Medium (needs `changes:`) |
| `comment.deleted` | ✅ `Comments::Delete` | ❌ | High |

### Reactions
| Event | Emitted today | Actor in payload | Tier |
|---|---|---|---|
| `reaction.created` | ✅ `Reactions::Toggle#add` | ❌ | **Low-signal** (high volume) |
| `reaction.removed` | ✅ `Reactions::Toggle#remove` | ❌ | **Low-signal** |

### Checklists / attachments
| Event | Emitted today | Actor | Tier |
|---|---|---|---|
| `checklist.created` / `checklist.updated` / `checklist.deleted` | ✅ `Checklists::*` | ❌ | Medium |
| `checklist_item.created` / `checklist_item.toggled` | ⚠️ verify in `ChecklistItems::*` | ❌ | **Low-signal** (chatty toggles) |

### Settings / exports
| Event | Emitted today | Actor | trip_id | Tier |
|---|---|---|---|---|
| `export.requested` | ✅ `Exports::RequestExport` | ✅ `user_id` | ✅ | Medium |

### Auth / access (app-wide — `trip_id` NULL, superadmin/General only)
| Event | Emitted today | Tier | Notes |
|---|---|---|---|
| `access_request.submitted/approved/rejected` | ✅ `AccessRequests::*` | High | Captured now; visible in Phase 22 superadmin console |
| `invitation.sent/accepted` | ✅ `Invitations::*` | High | Captured now |
| `auth.login/logout/password_changed/passkey_added` | ❌ Rodauth emits none | High | **Phase 22** — net-new emit points (flag #6) |

**High-signal vs noise summary:** Trip lifecycle, membership, entry/comment create-update-delete, checklist create/delete, exports, access/invitation = **high signal, always logged & shown**. Reactions and checklist-item toggles = **noise tier**: captured (an audit log that silently drops automated/bulk activity is worthless) but **hidden by default** in the trip feed behind a "Show low-signal activity" toggle.

---

## 5. Event Schema

Every persisted `AuditLog` row carries:

| Field | Type | Required | Purpose |
|---|---|---|---|
| `id` | uuid PK | ✅ | Project convention (`id: :uuid`) |
| `trip_id` | uuid, **nullable** | — | Trip context. **NULL** for app-wide events (access_request, invitation, future auth). No FK cascade — rows survive trip deletion. |
| `actor_id` | uuid, nullable, FK→users | — | Resolved actor. NULL ⇒ unattributable system action. |
| `actor_label` | string | ✅ | **Denormalised** display name at action time (e.g. `Marée`, `jack (agent)`, `System`). Survives user rename/deletion — an audit trail must not break when its subject is deleted. |
| `action` | string | ✅ | Canonical verb key = the `Rails.event` name (`journal_entry.created`). |
| `auditable_type` / `auditable_id` | string / uuid, nullable | — | Polymorphic target. Nullable + no FK so the row outlives a destroyed target. |
| `summary` | string | ✅ | Human sentence rendered at write time: `Marée updated journal entry "Mont Saint-Michel"`. Pre-rendered so reads need no joins. |
| `metadata` | json | ✅ (default `{}`) | Structured detail: `{ "changes": { "name": ["Old","New"] }, "from_state": "...", "to_state": "...", "target_name": "...", "removed_user_label": "..." }`. |
| `source` | integer enum | ✅ (default `web`) | `web:0, mcp:1, telegram:2, system:3` — who/what channel performed it. Drives UI badges and filtering. |
| `request_id` | string, nullable | — | Correlation id (`request.request_id`) to group actions from one request/batch. |
| `event_uid` | string, **unique** | ✅ | Idempotency key: `"#{request_id}:#{action}:#{auditable_id}"` (or `SecureRandom.uuid` when no request). Job `create!` rescues `RecordNotUnique` — mirrors `CreateNotificationJob`. |
| `occurred_at` | datetime | ✅ | When the action happened (event time). May precede `created_at` for delayed jobs / late Telegram syncs. |
| `created_at` / `updated_at` | datetime | ✅ | Row write time. `updated_at` never changes (append-only). |

Rationale for denormalisation (`actor_label`, `metadata.target_name`, `summary`): the audit log is **immutable and self-contained**. Reads render directly from the row with **zero association loads** — fast, N+1-proof, and correct even after the trip/entry/user is destroyed.

---

## 6. Permission Matrix

Two scopes. Trip-specific ships in Phase 21; General is data-only in Phase 21, console in Phase 22.

### Who can see the feed

| Role | Trip-specific feed (`/trips/:id/audit_logs`) | General/app-wide feed | Low-signal tier (reactions/toggles) |
|---|---|---|---|
| **superadmin** (user `roles_mask`) | ✅ Full, every trip | ✅ Phase 22 console (auth + access + invitations + all trips) | ✅ via toggle |
| **trip contributor** (`TripMembership.contributor?` on that trip) | ✅ Full, that trip only | ❌ never | ✅ via toggle |
| **trip viewer** (`TripMembership.viewer?`) | ❌ **nav hidden + route 404** | ❌ | — |
| **guest / non-member** | ❌ **nav hidden + route 404** | ❌ | — |

### What is hidden even from contributors

| Event class | Visible to trip contributor? | Rationale |
|---|---|---|
| All mutations within their trip (incl. membership add/remove, role changes within that trip) | ✅ Yes | Transparency within the trip the user co-owns. Flag #7 — confirm contributors should see *who removed whom*. |
| Cross-trip activity (other trips they're not on) | ❌ No | Trip isolation. Superadmin-only (General). |
| Auth/security events (login, passkey, password) | ❌ No | Security log = superadmin-only (General, Phase 22). |
| Access requests, invitations | ❌ No | App-wide admin domain. Superadmin-only (General). |

Authorization is enforced by a new `AuditLogPolicy` authorized against the **trip** (not the log): `superadmin? || trip_contributor?`. Non-authorised access raises → the `AuditLogsController` overrides the app-wide `ActionPolicy::Unauthorized → 403` to return **`head :not_found`** for this controller only, honouring Q2 "hidden entirely → 404" (flag #1).

---

## 7. UX of the Feed

| Concern | Phase 21 decision |
|---|---|
| **Grouping** | Primary: by **day** (`Today` / `Yesterday` / `15 May 2026` dividers), reverse-chronological within day. Secondary: consecutive same-`actor` + same-`request_id` bursts collapse into one summarised row (`Marée added 5 reactions`) — uses `request_id` correlation. |
| **Filtering** | One control only: a **"Show low-signal activity"** toggle (reactions, checklist-item toggles). Actor/action/date filters → Phase 22. |
| **Search** | Phase 22. |
| **Pagination** | No pagination gem in repo (lists use `.limit(50)`). Initial load `.limit(50)` ordered `occurred_at DESC, id DESC`; **"Load older"** button issues `GET ...?before=<occurred_at>&before_id=<id>` (keyset cursor) and appends the next 50. Stimulus `IntersectionObserver` auto-load is an optional enhancement. |
| **Real-time vs polled** | **Live, not polled.** New rows are pushed via `ActionCable.server.broadcast("audit_log:trip_#{trip_id}", { html: <rendered card> })`; a Stimulus controller prepends the HTML to the top of the current day group. Exact clone of the Notification Center mechanism. |
| **Diff rendering** | For `*.updated` rows with `metadata.changes`, render a compact list: `Name: "Old" → "New"`; values truncated at ~80 chars; `body`/rich-text shown as a neutral `body changed` chip (no HTML diff). `trip.state_changed` renders a `Planning → Started` pill pair. |
| **Empty state** | "No activity yet" with an icon, mirroring `Views::Notifications::Index` empty state. |
| **Actor rendering** | Avatar initials + `actor_label` + a `source` badge (`web` none, `mcp` = "Agent", `telegram` = "Telegram", `system` = "System"). |

---

## 8. Edge Cases

| Edge case | Handling |
|---|---|
| **Trip deletion** | `Trip has_many :journal_entries, dependent: :destroy` cascades the domain but **not** `audit_logs` (nullable `trip_id`, no FK). Today **no event is emitted on trip destroy** → audit blind spot. **New task:** add `Trips::Delete` action emitting `trip.deleted` and route `TripsController#destroy` through it. The audit row keeps `trip_id` + `metadata.target_name` snapshot, readable forever. |
| **Delete events emitted post-`destroy!`** *(found & fixed in PR #144 review — P1/P2)* | `comment.deleted` and `reaction.removed` are emitted **after** `destroy!`, so the builder cannot load the primary record — `Model.find_by(primary_id)` returns `nil` and the row was written with `trip_id: nil`, becoming an invisible app-wide row (the General console is Phase 22). Resolution: the builder resolves trip context from **surviving related IDs in the payload**, never from the destroyed record — comments via `journal_entry_id` (the entry survives a comment delete), reactions via `reactable_type`/`reactable_id` (mirrors `Reaction#trip`). Applied **unconditionally** so created and deleted share one path. `trip.deleted` / `journal_entry.deleted` / `trip_membership.removed` are unaffected because their actions already carry `trip_id` in the payload. Regression specs added for `comment.deleted` and `reaction.removed` (entry/comment/trip reactables). |
| **Member removal** | `trip_membership.removed` payload has `user_id` = the *removed* user, **not** the remover. Actor resolved via `Current.actor`. Row: `actor` = remover, `metadata.removed_user_label` = removed user's name snapshot. |
| **Role downgrades** | No role-change action exists today (`Assign` creates, `Remove` deletes; no update). Phase 21 logs add/remove only. If `trip_membership.role_changed` is added later it slots in with zero subscriber changes. Flag #5. |
| **Reverted actions** | No undo feature. The log is **append-only**: an "undo" is a new forward action and a new row. History is never mutated or deleted. |
| **Bulk imports** (Telegram/MCP batch) | **One row per entity** for fidelity; the UI **collapses by `request_id` + actor + action** into `imported 20 entries`. No special bulk event in Phase 21. |
| **System / automated actions** | Captured (not excluded — unlike email subscription which filters `@system.local`). `actor` = the agent's system `User`, `actor_label` = agent name, `source` = `mcp`/`telegram`/`system`. Visible in the feed with a source badge. |
| **Offline edits that sync later** (Telegram arrives late) | `occurred_at` = the event/message timestamp when known, else `Time.current`; `created_at` = row write time. Telegram already idempotent via `telegram_message_id`; the audit row is idempotent via the unique `event_uid` + `rescue RecordNotUnique`. |
| **Job backend down** | Fire-and-forget: the user action still succeeds; the audit row is lost. Acceptable for v1; flag #9 notes a transactional-outbox hardening for later. |
| **Subscriber raises** | `RecordAuditLogJob` is enqueued from a synchronous subscriber; wrap subscriber body in a rescue that logs and never re-raises into the user's request (a broken audit log must not break the app). |

---

## 9. Write/Read Characteristics

- **Volume estimate (one active ~2-week group trip):** ~50 entries, ~300 comments, ~800 reactions, ~150 checklist/toggle events ≈ **~1,300 audit rows/trip**. Reactions dominate (~60%) — hence the low-signal tier. App-wide scales linearly with trip count; trivial for SQLite/the project's scale.
- **Storage:** primary SQLite DB (Solid Queue uses a separate `queue` DB per `config/environments/production.rb`). `metadata` is a JSON column (SQLite `json`). UUID PKs per project convention.
- **Indexing strategy:**
  - `[trip_id, occurred_at, id]` — the hot path: `WHERE trip_id = ? ORDER BY occurred_at DESC, id DESC LIMIT 50` (keyset paginated). Covering for the feed.
  - `[occurred_at, id]` — General feed (Phase 22).
  - `[auditable_type, auditable_id]` — "history of this object".
  - `[actor_id]` — "everything this user did".
  - `[request_id]` — burst correlation.
  - `unique [event_uid]` — idempotency.
- **Reads need no joins** — fully denormalised. No N+1 (Bullet is active in specs; the design is join-free by construction).
- **Blocking vs async:** the user action is **never blocked**. The `Rails.event` subscriber is synchronous but does only O(1) in-memory work (resolve actor from already-loaded data, build hash, `perform_later`). The DB write + ActionCable broadcast happen in `RecordAuditLogJob` on Solid Queue. Logging failure degrades to a missing row, never a failed user action.

---

## 10. Codebase Context

File-by-file, the existing patterns this PRP composes (all verified):

### Event pipeline (the spine)
- `config/initializers/event_subscribers.rb` — registry. `Rails.event.subscribe(Subscriber.new) { |e| e[:name].start_with?("...") }`. **Phase 21 adds one line** registering `AuditLogSubscriber` for *all* relevant prefixes.
- `app/subscribers/notification_subscriber.rb` — **the exact template**: `#emit(event)` → `case event[:name]` → `SomeJob.perform_later(event[:payload][...], actor_id)`. `AuditLogSubscriber` mirrors this.
- `app/actions/base_action.rb` — `include Dry::Monads[:result, :do]`. All mutations are `Actions` that `yield persist` then `yield emit_event` returning `Success`. Payload enrichment is additive here.
- Payload reality (verified by reading the files): `trip.updated`→`{trip_id}`, `journal_entry.updated`→`{journal_entry_id, trip_id}`, `reaction.created`→`{reaction_id, reactable_type, reactable_id}`, `trip_membership.removed`→`{trip_membership_id, trip_id, user_id}` (no actor). Only `journal_entry.created`/`comment.created`/`trip_membership.created` carry `actor_id`; `export.requested` carries `user_id`.

### Async + live update (the Notification Center — clone this)
- `app/jobs/create_notification_job.rb` — `queue_as :default`; `Model.create!` then `rescue ActiveRecord::RecordNotUnique` (idempotent); private `broadcast_*` doing `ActionCable.server.broadcast("notifications:user_#{id}", {...})`. **`RecordAuditLogJob` copies this shape verbatim.**
- `app/channels/notifications_channel.rb` — `class NotificationsChannel < ApplicationCable::Channel; def subscribed; stream_from "notifications:user_#{current_user.id}"; end; end`. `AuditLogChannel` mirrors it with a trip stream + an authorization guard.
- `app/channels/application_cable/connection.rb` — already identifies `current_user` from `request.session[:account_id]` (Rodauth). No connection changes needed.
- `app/javascript/controllers/notification_badge_controller.js` — `createConsumer().subscriptions.create("NotificationsChannel", { received: (data) => ... })`. `audit_log_feed_controller.js` mirrors it but does `this.listTarget.insertAdjacentHTML("afterbegin", data.html)`.
- `app/javascript/controllers/index.js` — Stimulus registration (add the new controller).
- **No `turbo_stream_from` / `broadcasts_to` anywhere** — do **not** introduce turbo-rails streaming; the raw ActionCable + Stimulus pattern is the house standard. (Flag #8 if the team prefers Turbo Streams.)

### Feed UI (the Feed Wall — mirror this)
- `app/components/base.rb` (`Components::Base < Phlex::HTML`, includes `Phlex::Rails::Helpers::Routes`), `app/views/base.rb` (`Views::Base` adds `ContentFor`).
- `app/components/journal_entry_card.rb`, `app/components/comment_card.rb` — card recipe: `div(id: dom_id(@record), class: "rounded-2xl bg-[var(--ha-surface-low)] p-4 ...")`, private `render_*` methods.
- `app/views/notifications/index.rb` + `app/components/notification_card.rb` — **day-grouped feed with empty state** — the structural template for `Views::AuditLogs::Index` + `Components::AuditLogCard`.
- `app/controllers/notifications_controller.rb` — `authorize!(Notification)`, `render Views::Notifications::Index.new(...)`, `.recent.includes(...).limit(50)`.
- `app/controllers/concerns/turbo_streamable.rb` — **gotcha codified**: `render_to_string(component, layout: false)`. For broadcasting Phlex from a job use `ApplicationController.render(Component.new(...), layout: false)` (full view context incl. route helpers in a job).
- `app/components/sidebar.rb` — nav gating pattern: `if logged_in? && view_context.allowed_to?(:index?, AccessRequest)` → conditionally `render Components::NavItem.new(...)`. The Activity link is gated the same way. `NavItem` active state via `Components::NavItem::NAV_BASE`/`NAV_ACTIVE`.
- `config/routes.rb` — `resources :trips do ... end`; nested resources pattern (comments/reactions). Add `resources :audit_logs, only: [:index]` inside the trips block.

### Authorization
- `app/controllers/application_controller.rb` — `include ActionPolicy::Controller`, `authorize :user, through: :current_user`, global `rescue_from ActionPolicy::Unauthorized → Views::Shared::Forbidden (403)`. The audit controller **overrides** this to 404.
- `app/policies/application_policy.rb` — `superadmin? = user&.role?(:superadmin)`.
- `app/policies/trip_policy.rb` — the membership idiom to copy: `trip_membership = record.trip_memberships.find_by(user: user)`; `contributor? = trip_membership&.contributor?`.

### Models / actors
- `app/models/user.rb` — `system_actor?` = `email.end_with?("@system.local")`.
- `app/models/agent.rb` — `belongs_to :user` (system actor); `slug`, `name`.
- `app/models/notification.rb` — polymorphic + enum + scopes template for `AuditLog`.
- **No `ActiveSupport::CurrentAttributes` exists** — Phase 21 introduces `app/models/current.rb`.

### Tests / validation
- `spec/` is **RSpec**. Factories in `spec/factories/` (`:user` with `:superadmin`/`:contributor`/`:viewer`/`:system_actor` traits; `:trip`, `:journal_entry`, `:comment`, `:reaction`, `:trip_membership` `:viewer` trait, `:agent`).
- `spec/support/auth_helpers.rb` → `stub_current_user(user)` for request specs; `spec/support/system_auth_helpers.rb` → `login_as(user:)` for system specs; `spec/support/system_test.rb` → `:js` tag = `selenium_chrome_headless`.
- Rake tasks (`Rakefile`): `project:fix-lint`, `project:lint`, `project:tests` (excludes system), `project:system-tests`.

---

## 11. Data Model

Migration — **mirror `db/migrate/20260327100001_create_notifications.rb`** (`id: :uuid`, `t.references ..., type: :uuid`):

```ruby
# db/migrate/XXXXXXXXXXXXXX_create_audit_logs.rb
class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.references :trip,  type: :uuid, null: true, foreign_key: false # nullable, app-wide rows
      t.references :actor, type: :uuid, null: true,
                           foreign_key: { to_table: :users }
      t.string  :actor_label,    null: false
      t.string  :action,         null: false
      t.string  :auditable_type, null: true
      t.uuid    :auditable_id,   null: true
      t.string  :summary,        null: false
      t.json    :metadata,       null: false, default: {}
      t.integer :source,         null: false, default: 0
      t.string  :request_id,     null: true
      t.string  :event_uid,      null: false
      t.datetime :occurred_at,   null: false
      t.timestamps
    end

    add_index :audit_logs, %i[trip_id occurred_at id],            name: "idx_audit_logs_trip_feed"
    add_index :audit_logs, %i[occurred_at id],                    name: "idx_audit_logs_global_feed"
    add_index :audit_logs, %i[auditable_type auditable_id],       name: "idx_audit_logs_target"
    add_index :audit_logs, :actor_id,                             name: "idx_audit_logs_actor"
    add_index :audit_logs, :request_id,                           name: "idx_audit_logs_request"
    add_index :audit_logs, :event_uid, unique: true,              name: "idx_audit_logs_event_uid"
  end
end
```

```ruby
# app/models/audit_log.rb
class AuditLog < ApplicationRecord
  belongs_to :trip,      optional: true
  belongs_to :actor,     class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true,  optional: true

  enum :source, { web: 0, mcp: 1, telegram: 2, system: 3 }

  validates :actor_label, :action, :summary, :event_uid, :occurred_at, presence: true

  scope :recent,        -> { order(occurred_at: :desc, id: :desc) }
  scope :for_trip,      ->(trip) { where(trip_id: trip.id) }
  scope :app_wide,      -> { where(trip_id: nil) }
  scope :high_signal,   -> { where.not(action: LOW_SIGNAL_ACTIONS) }

  LOW_SIGNAL_ACTIONS = %w[
    reaction.created reaction.removed checklist_item.toggled
  ].freeze

  # Append-only: never updated or destroyed in normal flow.
  def readonly? = persisted?
end
```

`readonly? = persisted?` makes the row immutable after creation (append-only integrity, flag #7). It does not block `create!`.

---

## 12. Implementation Blueprint

### 12.1 Actor capture — the central design (read first)

Most events carry no actor (§4). The canonical Rails solution is `ActiveSupport::CurrentAttributes`, set in the request thread, read by the **synchronous** `Rails.event` subscriber:

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :actor      # User performing the action (or nil)
  attribute :request_id # request.request_id for correlation
  attribute :source     # :web | :mcp | :telegram | :system
end
```

```ruby
# app/controllers/application_controller.rb  (add)
before_action do
  Current.actor      = current_user
  Current.request_id = request.request_id
  Current.source     = :web
end
```

```ruby
# app/controllers/mcp_controller.rb  (add — set after the agent's system User is resolved)
Current.actor  = resolved_agent_user
Current.source = :mcp
Current.request_id = request.request_id
```

> **Load-bearing assumption (verify in Task 0):** Rails 8.1 `Rails.event.notify` dispatches subscribers **synchronously in the calling thread**, so `Current.actor` is still populated when `AuditLogSubscriber#emit` runs inside the same web/MCP request. The DB write is deferred to a job (where `Current` is *not* set) — therefore the subscriber must resolve the actor **now** and pass `actor_id`/`actor_label` as job arguments (exactly how `NotificationSubscriber` passes `actor_id` to `NotifyEntryCreatedJob`).

**Actor resolution priority** (in the subscriber, while synchronous):
1. `event[:payload][:actor_id]` if present (entry/comment/membership create).
2. `Current.actor`.
3. Record's intrinsic owner: `Trip#created_by_id`, `JournalEntry#author_id`, `Comment#user_id`, `Reaction#user_id`.
4. `nil` → `actor_label = "System"`, `source = :system`.

### 12.2 Diff capture — additive payload enrichment

The subscriber runs after the Action and only has IDs; a reloaded record has **no dirty state**. So capture the diff **at the mutation point** where `record.saved_changes` is live. Additive, one line per file:

```ruby
# app/actions/trips/update.rb  — emit_event(trip)
Rails.event.notify("trip.updated",
  trip_id: trip.id,
  actor_id: Current.actor&.id,
  changes: trip.saved_changes.except("updated_at", "created_at"))
```

Apply the same `changes:`/`actor_id:` enrichment to: `journal_entries/update.rb`, `journal_entries/delete.rb` (actor only), `comments/update.rb`, `comments/delete.rb` (actor only), `reactions/toggle.rb` (actor only, both branches), `trip_memberships/remove.rb` (actor only), `checklists/update.rb`, `trips/transition_state.rb` (actor only — `from/to_state` already present). Existing keys are untouched; subscribers tolerate missing keys.

> **Corollary — builder trip resolution (as-built, PR #144).** The "the record may be gone by the time the builder runs" rule applies to **trip scoping**, not just diffs. Delete/remove actions emit *after* `destroy!`, so `Builder#*_subject` must derive `trip_id` from payload-carried **sibling** IDs — `journal_entry_id` for comments, `reactable_type`/`reactable_id` for reactions (mirroring `Reaction#trip`) — **never** from `Model.find_by(primary_id)`, and unconditionally (one path for created and deleted). The original blueprint loaded the primary record in `comment_subject`/`reaction_subject`; review caught that `comment.deleted` (P1) and `reaction.removed` (P2) wrote `trip_id: nil`. Builder spec must include a deleted/removed example per entity, not only `journal_entry.deleted` (which passes only because its payload carries `trip_id`).

### 12.3 Subscriber → Job → Channel → Stimulus (clone Notification Center)

```ruby
# app/subscribers/audit_log_subscriber.rb
class AuditLogSubscriber
  def emit(event)
    attrs = AuditLog::Builder.new(event).call   # resolves actor, summary, metadata, trip_id, source, event_uid
    RecordAuditLogJob.perform_later(attrs) if attrs
  rescue StandardError => e
    Rails.logger.error("[audit] #{event[:name]} dropped: #{e.class} #{e.message}")
    # never re-raise into the user's request
  end
end
```

```ruby
# config/initializers/event_subscribers.rb  (add inside the after_initialize block)
Rails.event.subscribe(AuditLogSubscriber.new) do |e|
  e[:name].start_with?(
    "trip.", "trip_membership.", "journal_entry.", "comment.",
    "reaction.", "checklist", "export.", "access_request.", "invitation."
  )
end
```

`AuditLog::Builder` (a PORO under `app/models/audit_log/builder.rb` or `app/services/`): `case event[:name]` → loads the target by id, derives `trip_id` (nil for access_request/invitation), resolves actor (§12.1), builds `summary` + `metadata` (incl. `changes`, `target_name`, `from/to_state`, `removed_user_label`), computes `event_uid`, picks `source` from `Current.source`/payload. Returns a plain Hash (job-serialisable) or `nil` to skip.

```ruby
# app/jobs/record_audit_log_job.rb  (shape = CreateNotificationJob)
class RecordAuditLogJob < ApplicationJob
  queue_as :default

  def perform(attrs)
    log = AuditLog.create!(attrs)
    broadcast(log) if log.trip_id
  rescue ActiveRecord::RecordNotUnique
    # idempotent: row already written (job retry / Telegram resync)
  end

  private

  def broadcast(log)
    html = ApplicationController.render(
      Components::AuditLogCard.new(audit_log: log), layout: false
    )
    ActionCable.server.broadcast("audit_log:trip_#{log.trip_id}",
                                 { html: html, low_signal: log.low_signal? })
  end
end
```

```ruby
# app/channels/audit_log_channel.rb
class AuditLogChannel < ApplicationCable::Channel
  def subscribed
    trip = Trip.find_by(id: params[:trip_id])
    return reject unless trip && AuditLogPolicy.new(trip, user: current_user).index?

    stream_from "audit_log:trip_#{trip.id}"
  end
end
```

```js
// app/javascript/controllers/audit_log_feed_controller.js  (mirror notification_badge_controller.js)
import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
export default class extends Controller {
  static targets = ["list"]
  static values  = { tripId: String, showLowSignal: Boolean }
  connect() {
    this.sub = createConsumer().subscriptions.create(
      { channel: "AuditLogChannel", trip_id: this.tripIdValue },
      { received: (d) => {
          if (d.low_signal && !this.showLowSignalValue) return
          this.listTarget.insertAdjacentHTML("afterbegin", d.html)
      } })
  }
  disconnect() { this.sub?.unsubscribe() }
}
```

### 12.4 Controller / policy / route / nav

```ruby
# app/policies/audit_log_policy.rb  — authorized against the Trip
class AuditLogPolicy < ApplicationPolicy
  authorize :user, allow_nil: true
  def index? = superadmin? || trip_contributor?
  private
  def trip_contributor?
    record.is_a?(Trip) &&
      record.trip_memberships.find_by(user: user)&.contributor?
  end
end
```

```ruby
# app/controllers/audit_logs_controller.rb
class AuditLogsController < ApplicationController
  before_action :require_authenticated_user!

  # Q2 / flag #1: "hidden entirely" → 404 (override app-wide 403 for this controller only)
  rescue_from ActionPolicy::Unauthorized do
    respond_to { |f| f.any { head :not_found } }
  end

  def index
    @trip = Trip.find(params[:trip_id])
    authorize! @trip, with: AuditLogPolicy
    scope = AuditLog.for_trip(@trip).recent
    scope = scope.high_signal unless params[:low_signal] == "1"
    scope = scope.where("occurred_at < ?", params[:before]) if params[:before].present?
    @audit_logs = scope.limit(50)
    render Views::AuditLogs::Index.new(trip: @trip, audit_logs: @audit_logs,
                                       show_low_signal: params[:low_signal] == "1")
  end
end
```

```ruby
# config/routes.rb  — inside `resources :trips do`
resources :audit_logs, only: [:index]
```

```ruby
# app/components/sidebar.rb / trip page — gate the link (copy the AccessRequest idiom)
if logged_in? && @trip && AuditLogPolicy.new(@trip, user: current_user).index?
  render Components::NavItem.new(path: trip_audit_logs_path(@trip),
                                 label: "Activity", icon: Components::Icons::Clock.new, ...)
end
```

`Views::AuditLogs::Index` + `Components::AuditLogCard`: structural clone of `Views::Notifications::Index` + `Components::NotificationCard` — day dividers, `data-controller="audit-log-feed"` with `data-audit-log-feed-trip-id-value`, `#audit_log_list` target, empty state, "Load older" link, low-signal toggle, diff block. **Use only existing compiled `--ha-*` Tailwind classes** (memory: new classes need a Docker rebuild). Pick an existing icon in `app/components/icons/` (do not invent one without rebuilding).

---

## 13. Task List (ordered)

Each task = one atomic commit + green `project:tests` (memory: small, reversible commits). Follow the `/execution-plan` skill (issue → Kanban → branch → commits → tests → live verify → PR → review).

0. **Spike (no commit):** in `bin/rails console`, confirm `Rails.event.notify` runs subscribers synchronously in the caller thread (set a `Current.actor`, emit, assert a probe subscriber saw it). If false, fall back to enriching **all** payloads with `actor_id` instead of relying on `Current` (the §12.2 enrichment already covers most; widen it). Record the result in `prompts/Phase 21 - Steps.md`.
1. **Migration + model + factory + model spec.** `create_audit_logs`; `AuditLog` (enum, scopes, `readonly?`); `spec/factories/audit_logs.rb`; `spec/models/audit_log_spec.rb`. Run `bin/rails db:migrate` then commit schema (overcommit `RailsSchemaUpToDate`).
2. **`Current` + controller wiring + spec.** `app/models/current.rb`; `before_action` in `ApplicationController`; set in `McpController`; `spec/models/current_spec.rb` + a request spec asserting `Current.actor` is the signed-in user.
3. **Payload enrichment.** Add `actor_id:`/`changes:` to the ~8 actions in §12.2. Update each action's spec to assert the new payload keys. Purely additive.
4. **`AuditLog::Builder` + spec.** Actor priority chain, summary/metadata/`event_uid`/`source`/`trip_id` per event family. Exhaustive `spec/models/audit_log/builder_spec.rb` (one example per event name — this is where correctness lives).
5. **`AuditLogSubscriber` + registration + spec.** Add to `event_subscribers.rb`; `spec/subscribers/audit_log_subscriber_spec.rb` asserts `RecordAuditLogJob` enqueued and never raises on bad input.
6. **`RecordAuditLogJob` + spec.** `create!` + `rescue RecordNotUnique` + broadcast; `spec/jobs/record_audit_log_job_spec.rb` (idempotency, broadcast only when `trip_id`).
7. **`Trips::Delete` action + wire `TripsController#destroy` + specs.** Emits `trip.deleted` (closes the §8 trip-deletion gap, flag #4).
8. **Policy + controller + route + spec.** `AuditLogPolicy`; `AuditLogsController` with 404 override; nested route; `spec/policies/audit_log_policy_spec.rb`, `spec/requests/audit_logs_spec.rb` (superadmin 200, contributor 200, viewer 404, guest 404, keyset `before`, low-signal toggle).
9. **`AuditLogChannel` + Stimulus + register in `index.js`.** `spec/channels/audit_log_channel_spec.rb` (rejects non-contributor).
10. **Phlex `Views::AuditLogs::Index` + `Components::AuditLogCard`** (day grouping, diff block, source badge, empty state, load-older, low-signal toggle) + nav link gating in `Sidebar`/trip page.
11. **System spec** `spec/system/audit_logs_spec.rb`: contributor sees feed; create an entry in another tab/`:js` → row appears without reload; diff renders for an edit; agent-authored row shows agent label + "Agent" badge; viewer hits 404.
12. **Docs + Stitch + phase docs.** Update `CLAUDE.md` (Audit Journal section: actor model, append-only, source enum, 404 deviation); create `prompts/Phase 21 - Audit Log - Google Stitch Prompt.md` from §17; create `prompts/Phase 21 - Steps.md` audit-trail scaffold.
13. **Validation gates + runtime verification** (§15–§16).

---

## 14. Testing Strategy

| Level | Coverage |
|---|---|
| **Model** (`spec/models/audit_log_spec.rb`) | enum, scopes (`recent`/`for_trip`/`app_wide`/`high_signal`), `readonly?` blocks update, presence validations. |
| **Builder** (`spec/models/audit_log/builder_spec.rb`) | One example **per `Rails.event` name** asserting `action`, `actor_label`, `summary`, `metadata.changes`, `trip_id` (nil for access_request/invitation), `source`, `event_uid` determinism. The correctness core. |
| **Subscriber** (`spec/subscribers/...`) | enqueues `RecordAuditLogJob`; swallows builder errors (never raises). |
| **Job** (`spec/jobs/...`) | creates row; `rescue RecordNotUnique` idempotent; broadcasts only when `trip_id` present. |
| **Action specs** (existing, extended) | new `actor_id:`/`changes:` payload keys present; existing assertions unchanged. |
| **Policy** (`spec/policies/audit_log_policy_spec.rb`) | superadmin ✅; trip contributor ✅; viewer ❌; guest ❌; non-member ❌. |
| **Request** (`spec/requests/audit_logs_spec.rb`) | `stub_current_user`: superadmin/contributor → 200; viewer/guest → **404**; `?before=` keyset; `?low_signal=1` toggle. |
| **Channel** (`spec/channels/audit_log_channel_spec.rb`) | contributor subscribes; viewer rejected. |
| **System** (`spec/system/audit_logs_spec.rb`, `:js`) | live prepend without reload; day grouping; diff block; agent attribution + source badge; viewer 404. Use `login_as(user:)`, factories `:user`/`:trip`/`:trip_membership`/`:agent`. |

---

## 15. Validation Gates (Executable)

Per `AGENTS.md` §3 — run in order, all green before pushing:

```bash
bundle exec rake project:fix-lint
bundle exec rake project:lint
bundle exec rake project:tests
bundle exec rake project:system-tests
```

Overcommit runs RuboCop, ErbLint, trailing-whitespace, FixMe, **RailsSchemaUpToDate** on every commit. After the migration, commit `db/schema.rb` in the same commit; if a non-schema commit trips `RailsSchemaUpToDate` falsely use `SKIP=RailsSchemaUpToDate git commit ...` with a footnote (memory: skip only the specific hook, document why). CI mirrors these (`.github/workflows/ci.yml`); `PRPs/**` and `prompts/**` are in `paths-ignore` so doc-only commits don't trigger CI (do **not** use `[skip ci]`).

---

## 16. Runtime Test Checklist

Mandatory live verification (`AGENTS.md` §5 / `/product-review` skill). Build runtime fixtures with **FactoryBot** via `docker exec -i <c> bin/rails runner - < /tmp/x.rb` (CLAUDE.md — raw `create!` misses required associations).

- [ ] `bin/cli app rebuild` succeeds (required: new Stimulus controller, new Tailwind usage compiled)
- [ ] `bin/cli app restart` health check passes
- [ ] `bin/cli mail start` running
- [ ] As superadmin: visit `/trips/:id/audit_logs` → feed renders, day-grouped
- [ ] Edit the trip in another browser/tab → new audit row **appears without reload** (ActionCable)
- [ ] Edit a journal entry → diff block renders `Name: "old" → "new"`
- [ ] Trigger an MCP agent write (per `trip-journal-mcp` skill) → row shows agent label + "Agent" badge, `source=mcp`
- [ ] Delete a trip → `trip.deleted` row exists and survives (trip gone)
- [ ] As trip **viewer**: nav link absent; `GET /trips/:id/audit_logs` → **404**
- [ ] Low-signal toggle hides/shows reactions
- [ ] Dark mode renders the feed correctly; no console errors
- [ ] Fix any runtime error, commit, re-run §15 before pushing

---

## 17. Google Stitch Prompt

> Save as `prompts/Phase 21 - Audit Log - Google Stitch Prompt.md`. Format mirrors `prompts/Phase 15 - Feed Wall Design Prompt.md`.

```
# Google Stitch Prompt — Trip Activity (Audit Journal)

## App Context
Catalyst is a collaborative trip-planning web app (desktop-first, fully responsive,
Material 3 expressive language). It already has a "Feed Wall" of journal-entry cards
and a Notification Center. This screen is the **Trip Activity** journal: an append-only,
chronological audit feed of every action taken on a single trip, visible only to trip
contributors and superadmins. Reuse the existing Catalyst M3 design system and the
Feed Wall's visual language exactly — do NOT invent a new palette.

## Colour System (use the existing `--ha-*` CSS custom properties)
### Light mode
- Background: `--ha-bg` (app canvas)
- Card: `--ha-surface-low` rounded-2xl, soft shadow
- Surface variant / row hover: `--ha-surface-container`
- Primary / links / active: `--ha-primary`
- Primary container (accent wash): `--ha-primary-container` at 10% opacity
- Text: `--ha-text`; Muted/metadata: `--ha-on-surface-variant`
- Danger (delete actions): `--ha-danger`
### Dark mode
- Mirror via the `.dark` token block already defined in
  `app/assets/tailwind/application.css` (glass sidebar, blurred surfaces). Dark variant required.

## Typography
- Headline font = the existing Catalyst headline utility
- Page title "Activity": text-4xl md:text-5xl, bold, tight tracking
- Day divider label ("Today", "Yesterday", "15 May 2026"): text-xs, uppercase,
  letter-spacing wide, `--ha-on-surface-variant`
- Actor name: text-sm, semibold, `--ha-text`
- Action summary: text-sm, regular
- Timestamp + source badge: text-xs, `--ha-on-surface-variant`

## Component Patterns
- Timeline rail: a thin vertical line on the left of each day group with a small
  node dot per entry (node tinted `--ha-primary` for high-signal, muted for low-signal)
- Audit row card: rounded-2xl, p-4, hover lifts to `--ha-surface-container`,
  fade-in on insert (motion-safe)
- Actor avatar: 40px rounded-2xl, gradient-aura initials (same as Sidebar avatar)
- Source badge chip: tiny pill — "Agent" / "Telegram" / "System" (no chip for web)
- Diff block: monospace, two-column "field → old → new", old struck-through in
  `--ha-danger`, new in `--ha-primary`; rich-text shows a neutral "body changed" chip
- State-change pill pair: "Planning" → "Started" rounded chips with an arrow
- Low-signal toggle: a switch in the page header — "Show reactions & checks"
- "Load older" ghost button at the foot of the list
- Empty state: clock icon + "No activity yet" (mirror Notifications empty state)

## Design Request: Trip Activity (4 screens)
### Screen 1 — Trip Activity, Desktop, Light
Two-column app shell (existing glass Sidebar + main). Main: page header "Activity"
with the low-signal toggle on the right. Below, day groups: divider label, then a
timeline rail of rows. Sample rows (realistic data):
- "Marée created journal entry 'Visited Mont Saint-Michel'" — Agent badge — 2 min ago
- "Joel updated trip — Dates: '12–18 May' → '12–20 May'" (diff block) — 1 h ago
- "Joel changed trip state" — Planning → Started pill — 3 h ago
- "Alex removed Sam from the trip" — `--ha-danger` accent — Yesterday
- collapsed: "Marée added 5 reactions" (burst group, low-signal, dimmed)
### Screen 2 — Trip Activity, Desktop, Dark (same content, dark tokens)
### Screen 3 — Trip Activity, Mobile (single column, Sidebar → bottom nav;
  timeline rail thinner, cards full-width, day divider sticky on scroll)
### Screen 4 — States: (a) empty state; (b) a row with the diff block expanded
  showing multi-field changes; (c) the viewer "not available" — actually omit:
  viewers never reach this screen (route 404s) — show instead the low-signal
  toggle ON revealing dimmed reaction rows.

## Interaction Patterns to Visualise
1. A new row fades/slides in at the top of "Today" in real time (no reload).
2. Toggling "Show reactions & checks" reveals dimmed low-signal rows in place.
3. "Load older" appends an older day group below.

## Explicitly NOT in this design
- Do NOT design search or actor/date filter UI (Phase 22).
- Do NOT design the superadmin app-wide/General console (Phase 22).
- Do NOT design any edit/delete affordance — the log is append-only & read-only.
- Do NOT design auth/login event rows (Phase 22).

## Design Constraints
- Desktop ≥ 1280px two-column; mobile ≤ 640px single column + bottom nav
- Rounded corners: cards rounded-2xl, chips rounded-full
- Spacing: space-y-3 between rows, space-y-8 between day groups
- Animations: motion-safe fade/slide on insert only; respect prefers-reduced-motion
- Both modes required; light primary
- Accessibility: WCAG AA contrast, ≥44px touch targets, time as <time datetime>,
  source badge has visible text (not colour-only)
```

---

## 18. Decisions to Push Back to the Team

Flag these before they bake in:

1. **404 vs 403 inconsistency.** Q2 ("hidden entirely → 404") forces the audit controller to override the app-wide `ActionPolicy::Unauthorized → 403 Forbidden` convention. Recommend confirming: a per-controller 404 is intentional concealment but is inconsistent with the rest of the app. Alternative: keep 403 + hide the nav link (still "hidden" in UI).
2. **Reactions/toggles volume.** ~60% of rows. Recommend the low-signal tier (captured, hidden by default). Confirm reactions should be audited at all vs. excluded entirely.
3. **Body/rich-text diffs.** Phase 21 shows "body changed" (no HTML diff). Confirm acceptable; true prose diffing is non-trivial and deferred.
4. **Trip-deletion audit gap.** No `Trips::Delete` action emits an event today. Recommend the small new action (Task 7). Confirm trip deletion should be audited (it should — destructive, high-signal).
5. **Role-change events.** No role-change action exists; Phase 21 logs membership add/remove only. Confirm acceptable until a role-change feature ships.
6. **`Current` introduction.** Actor capture requires a new app-wide `ActiveSupport::CurrentAttributes` primitive set in `ApplicationController` + `McpController`. Canonical, but foundational — confirm.
7. **Append-only integrity & contributor visibility.** Recommend no UI/route ever edits/deletes audit rows (`readonly? = persisted?`). Confirm contributors should see *who removed whom* / membership changes within their trip (transparency vs. privacy).
8. **No Turbo Streams.** Phase 21 uses raw ActionCable + Stimulus (the only in-repo live pattern). If the team wants to standardise on turbo-rails broadcasting, that's a separate cross-cutting decision.
9. **Fire-and-forget durability.** If Solid Queue is down, audit rows are lost (user action still succeeds). Acceptable v1; recommend a transactional-outbox/`after_commit` hardening on the Phase 22 roadmap.
10. **Privacy / GDPR.** An immutable per-user action log has data-retention and right-to-erasure implications. The team must define a retention/anonymisation policy before GA — Phase 22, but decide the policy now.

---

## 19. Documentation Updates

- `CLAUDE.md` — add an "Audit Journal" section: actor model (`Current` + resolution chain), `Rails.event` synchronous-dispatch dependency, append-only `readonly?`, `source` enum, the deliberate 404 deviation, low-signal tier.
- `prompts/Phase 21 - Audit Log - Google Stitch Prompt.md` — from §17.
- `prompts/Phase 21 - Steps.md` — append-only audit trail (issue/Kanban link, Task 0 spike result, commit table, deviations, validation + runtime results) per the project's Steps convention.
- `prompts/Phase 21 - Audit Log.md` — short phase-plan pointer to this PRP (workflow continuity for `/execution-plan`).
- `README.md` — one line under features if a features list exists.

---

## 20. Rollback Plan

Additive and isolated — low blast radius:
- Remove the `AuditLogSubscriber` line from `config/initializers/event_subscribers.rb` → all capture stops instantly; the rest of the app is unaffected (subscriber is the only coupling; payload enrichment is inert extra keys).
- `bin/rails db:rollback` drops `audit_logs` (no other table FKs into it).
- Revert the `audit_logs` route/controller/nav commit → feature invisible.
- `Current`, the additive payload keys, and `Trips::Delete` are harmless if left (other code ignores them); revert per-commit if desired (commits are atomic).

---

## 21. Out of Scope / Phase 22

- Superadmin **General/app-wide console** (the captured app-wide + cross-trip + auth rows get a UI).
- Net-new **auth event emit points** (Rodauth login/logout/password/passkey).
- Full-text **search**, actor/action/date **filters**, export of the audit log.
- `trip_membership.role_changed` (once a role-change feature exists).
- Rich-text/prose **diffing**.
- **Retention / GDPR** anonymisation & purge tooling.
- Transactional-outbox durability hardening.

---

## 22. Reference Documentation

- Rails 8.1 structured events (`Rails.event`, `ActiveSupport::EventReporter`): https://api.rubyonrails.org/v8.1/classes/ActiveSupport/EventReporter.html and https://guides.rubyonrails.org/
- `ActiveSupport::CurrentAttributes`: https://api.rubyonrails.org/v8.1/classes/ActiveSupport/CurrentAttributes.html
- `ApplicationController.render` (render views/Phlex outside a request, e.g. in a job): https://guides.rubyonrails.org/action_controller_overview.html#using-render
- Action Cable broadcasting: https://guides.rubyonrails.org/action_cable_overview.html
- Solid Queue: https://github.com/rails/solid_queue
- ActionPolicy (authorize against a custom record/context): https://actionpolicy.evilmartians.io/
- Phlex (Rails integration, rendering to string): https://www.phlex.fun/
- dry-monads `Result`/`Do`: https://dry-rb.org/gems/dry-monads/
- In-repo precedents to copy: `app/jobs/create_notification_job.rb`, `app/subscribers/notification_subscriber.rb`, `app/channels/notifications_channel.rb`, `app/javascript/controllers/notification_badge_controller.js`, `app/views/notifications/index.rb`, `app/components/notification_card.rb`, `db/migrate/20260327100001_create_notifications.rb`.

---

## 23. Quality Checklist

- [x] All necessary context included — file paths, verbatim patterns, verified payload shapes, the Notification Center as a 1:1 template
- [x] Validation gates are executable by AI — exact `rake` tasks + `/product-review`/`/execution-plan` skills
- [x] References existing patterns — subscriber/job/channel/Stimulus/Phlex/policy/migration precedents named with paths
- [x] Clear implementation path — 14 atomic, ordered tasks, each a commit + green tests, with a Task 0 spike de-risking the one load-bearing assumption
- [x] Error handling documented — subscriber swallows errors, job idempotent (`rescue RecordNotUnique`), fire-and-forget degradation, 404 override
- [x] Product scoping complete — taxonomy, schema, permission matrix, UX, edge cases, write/read characteristics, Stitch prompt, pushback flags
- [x] Ambiguities resolved with the owner, not guessed (§1)
- [x] Append-only + denormalised so the log survives deletion of its subjects

---

## 24. Skill Self-Evaluation

**Skill used:** generate-prp

**Step audit:**
- Codebase analysis, external research, user clarification, ULTRATHINK, write — all followed. The clarification step was load-bearing (the brief's role model contradicted the codebase's two-tier roles); `AskUserQuestion` resolved four design-forking ambiguities before writing, exactly as the skill's "User Clarification (if needed)" step intends.
- `PRPs/templates/prp_base.md` does not exist (the directory is empty); existing `PRPs/*.md` were used as the de-facto template instead. No step was wasted.
- The `context7` MCP and websearch were not needed — every pattern had a verified in-repo precedent, which is stronger context than external docs for a one-pass build; external URLs were still included per the skill.

**Improvement suggestion:** The skill says "Using `PRPs/templates/prp_base.md` as template" but that file/dir is empty in this project. Add a fallback line: "If `PRPs/templates/prp_base.md` is absent, infer the house structure from the most recent 2–3 `PRPs/*.md` files." This removes a dead reference and prevents an agent from blocking on a missing template.
