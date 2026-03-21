
# Trip Journal - Repo-aware Prompt

**Role and Objective**

Act as a Staff-Level Ruby on Rails Architect and Project Manager. Your objective is to draft a comprehensive, execution-ready implementation plan for a private Trip Journal Web App.

You are working inside the repository and must inspect the codebase before planning. Your plan must be grounded in what already exists in the repo, clearly separating confirmed findings from assumptions.

Produce an implementation plan only.
Do not write code.
Do not introduce replacement libraries.
Do not invent repo state when something is absent or unclear.

---

# Project Brief: Trip Journal Web App & Local MCP Integration

## 1. Product Context & Vision

We are building a highly structured, invite-only Trip Journal Web Application designed primarily as a mobile-first PWA.

The app is both:
- a read/write interface for users and invited participants, and
- an AI-assisted journaling system where the primary writer during a trip is an OpenClaw AI assistant named **Jack**.

The core interaction model is:

- I chat with Jack via Telegram while traveling.
- Jack connects to the application through a local MCP Server using Agent Skills.
- Jack can author journal entries on my behalf, manage checklist state, update trip state/details, and perform other allowed trip actions.
- Jack writes in the **first person on my behalf**.

This is a **private** app, not a public social platform.

### V1 Scope Boundaries

The following are explicitly **out of scope for V1** unless already present in the repository:

- WhatsApp support
- generic channel-to-trip pairing
- offline PWA capabilities
- PDF export implementation
- additional role types beyond the ones listed below
- replacement libraries or alternative frontend build tooling

For V1, there is **no persistent messaging-channel pairing model**. Assume Telegram is the only AI messaging ingress for now. If trip context resolution is needed for Jack, plan a simple V1-safe approach such as explicit active-trip context, but do **not** introduce a generalized `Channel` routing domain model in V1.

---

## 2. Privacy, Access, and Onboarding Flow

The application is invite-only.

### Public Landing
- Public visitors see a static landing page explaining the app is private.
- The page includes a **Request Access** action that submits an email address.

### Approval Flow
- A **Super Admin** receives an email notification for each access request.
- The Super Admin reviews the request and can send an invitation link.

### Signup & Assignment
- The invited user creates an account.
- The Super Admin is notified after signup.
- The Super Admin assigns the user to one or more Trips.
- The user receives an email containing the Trip URL.

### Roles

Use only these V1 roles:

#### Super Admin
- Global role
- Manages all users
- Reviews access requests
- Sends invitations
- Creates trips
- Assigns users to trips
- Has full administrative visibility

#### Contributor
Trip-scoped role with permission to:
- view trips, journal entries, comments, and checklists
- react and comment
- add, update, and delete journal entries
- update trip details
- update checklist state/content as permitted by plan

Contributor cannot:
- create trips
- delete trips
- manage global users unless explicitly justified by existing repo conventions

#### Viewer
Trip-scoped role with permission to:
- view trips, journal entries, comments, and checklists
- react and comment

Viewer cannot:
- create, update, or delete journal entries
- update trip details
- manage trips or memberships

A user may belong to **multiple trips** in V1.

---

## 3. Non-Negotiable Technical Stack

Do not introduce replacement libraries.

### Core
- Rails **8.1** already exists in the repo. Confirm the exact patch version from the repository.
- SQLite with UUID primary keys
- Propshaft

### Frontend
- Hotwire
- Turbo Rails
- Stimulus Rails
- importmap-rails
- tailwindcss-rails
- Tailwind UI components, templates, and UI kit
- Phlex

### Auth / Authorization
- Rodauth
- Passkeys / WebAuthn
- Action Policy, enforced at the controller level

### Background / Infra
- solid_cable
- solid_cache
- solid_queue
- Thruster
- Kamal

### Storage
- Active Storage
- SeaweedFS as the backing object store for persistent file storage
- Plan this as Active Storage using an S3-compatible service backed by SeaweedFS
- Do not propose ephemeral local storage under Kamal for uploaded media

### Rich Text
- Action Text is the canonical storage layer for rich text and embedded attachments
- Lexxy acts strictly as the editor layer
- Lexxy is expected to override Action Text defaults unless the repository shows otherwise:
  `config.lexxy.override_action_text_defaults = true`

### AI / Integration
- Local MCP Server using Agent Skills / agentskills.io

### Export
- Markdown export for Obsidian
- ePub export using Gepub
- Grover for PDF is a future/post-V1 concern only, unless groundwork already exists in the repository

### PWA
- Mobile-first PWA
- camera access is explicitly out of scope for V1
- GPS/location access is explicitly out of scope for V1
- push notifications
- offline support is explicitly out of scope for V1

### Frontend Constraint
All frontend integrations must remain **importmap-compatible**.
Do not propose npm, Vite, jsbundling, or a different JS toolchain.

---

## 4. Architecture and Domain Rules

### Strict Business Logic Separation

All business logic must be isolated from controllers and models using this structure:

1. **Actions (`app/actions`)**
   - PORO result objects
   - use `Dry::Monads[:result, :do]`
   - controllers call Actions only

2. **Events**
   - use **Rails.event structured event reporting** on Rails 8.1
   - Actions emit structured event objects
   - do not design a mixed incompatible event pipeline

3. **Subscribers**
   - subscribers must be compatible with Rails.event structured events
   - subscribers trigger workflows and side effects

4. **Workflows (`app/jobs/workflows`)**
   - Active Job continuations / step-based workflows
   - handle side effects such as notifications, delivery, async processing, export generation, etc.

### Authorization
- Authorization must be enforced at the controller level with Action Policy
- The plan should define policy boundaries by role and resource

---

## 5. Core Domain Constraints

### Trip
A Trip must support:
- `name`
- `description`
- `state`
- `metadata` as **JSON**, explicitly not JSONB
- optional `start_date`
- optional `end_date`

Trip states:
- `planning`
- `started`
- `cancelled`
- `finished`
- `archived`

### Journal Entry
A Journal Entry must support:
- `trip_id`
- `name`
- `description`
- `entry_date`
- `location_name`
- `latitude`
- `longitude`
- rich text body stored canonically with Action Text
- embedded images through Active Storage

Journal entries may be created retroactively and must render chronologically based on the canonical ordering rules below.

### Idempotency for Jack / Telegram
Entries created via MCP / Jack must include enough information to prevent duplicates caused by Telegram retries.

At minimum, plan for:
- `telegram_message_id`
- actor attribution indicating the action was performed by Jack on behalf of a user
- any additional audit/context fields you believe are necessary for safe idempotent processing

Do not design generic multi-provider channel routing for V1.

### Checklist
Hierarchical structure:
- Trip
  - Checklist
    - ChecklistSection
      - ChecklistItem

Checklist items have open/closed state.

### Social Interaction
- Comments belong to Journal Entries and Users
- Emoji Reactions are allowed on:
  - Trips
  - Journal Entries
  - Comments

### Access / Onboarding
Include explicit planning for:
- `AccessRequest`
- `Invitation`

### Membership
Users can belong to multiple trips.
Use an explicit join model such as `TripMembership` for trip-scoped participation and role assignment.

Do not introduce extra trip role types such as owner/admin for V1.

---

## 6. Chronology and Derived Date / Location Rules

These rules are required and should be treated as canonical in the plan.

### Canonical Journal Entry Order
Journal entries must be displayed in chronological order using:

1. `entry_date` ascending
2. `created_at` ascending
3. `id` ascending as a deterministic final tiebreaker

This means:
- if a new entry is created later but has an earlier `entry_date`, it must appear earlier in the trip chronology
- retroactive entries can reorder the visible timeline

### Derived Trip Start and End Dates
Trips may optionally have explicit `start_date` and `end_date`.

Rules:
- `Trip.start_date` uses the explicit stored `start_date` if present
- otherwise it defaults to the earliest chronological `JournalEntry.entry_date`
- `Trip.end_date` uses the explicit stored `end_date` if present
- otherwise it defaults to the latest chronological `JournalEntry.entry_date`

Explicit trip dates override derived defaults and should not be silently rewritten by later journal entries.

### Derived Trip Start and End Locations
Trip start/end locations are derived dynamically from the trip chronology.

Rules:
- derived start location comes from the **earliest chronological journal entry**
- derived end location comes from the **latest chronological journal entry**
- use the boundary entry’s `location_name`, `latitude`, and `longitude`
- if the relevant boundary entry has no location data, the derived trip location is `nil` / absent
- do not scan forward or backward to find a substitute location unless you explicitly call that out as a future enhancement outside V1

The plan must account for the fact that retroactive entries may change the derived boundary locations when chronology changes.

---

## 7. Export Requirements

### V1 Export Formats
Plan V1 export architecture for:
- Markdown (Obsidian-friendly)
- ePub

### Export Inclusion Rules
Include:
- trip core content
- journal entry text
- journal entry images stored in Active Storage

Exclude:
- comments
- reactions
- checklists

### PDF
- Grover-based PDF export is out of scope for V1
- you may mention future readiness only if relevant
- do not sequence PDF delivery into V1 unless the repository already contains significant groundwork

---

## 8. Repository Inspection Task

Before proposing the implementation plan, inspect the repository and summarize what is already present.

Your first section must be a **Repository Audit Snapshot** that clearly distinguishes:
- **Confirmed from repo**
- **Missing / not yet present**
- **Assumptions that still need verification**

Where possible, reference the relevant file paths or directories as evidence.

Audit the following:

1. exact Rails 8.1 patch version
2. installed gems and relevant initializers
3. Rodauth and passkey / WebAuthn setup
4. Solid Queue / Solid Cache / Solid Cable configuration
5. Active Storage setup and any SeaweedFS preparation
6. PWA scaffolding and notification-related groundwork
7. Phlex / Tailwind / Lexxy presence and integration points
8. Propshaft / importmap / Hotwire setup
9. deployment files, Kamal config, Thruster config, CI files
10. any MCP-related code, Agent Skills files, or integration scaffolding
11. Action Policy presence and current policy structure
12. Action Text and Lexxy integration details, including whether Lexxy overrides Action Text defaults
13. evidence of workflow/job continuation patterns already present, if any

If something is absent, say so plainly.
Do not fabricate repository state.

If repository access is unexpectedly unavailable in that session, state that explicitly and then provide a verification checklist rather than pretending the audit was completed.

---

## 9. Planning Requirements

After the repository audit, produce an implementation plan only.

Your output must include the following sections:

### 1. Assumptions and Open Questions
- include assumptions that remain after repo inspection
- include any product ambiguities that materially affect architecture or sequencing
- keep questions tightly scoped and actionable

### 2. Proposed Data Model
- list the core entities and relationships
- include recommended enums, JSON fields, audit/idempotency fields, and important constraints
- distinguish global-role data from trip-scoped role data
- account for AccessRequest, Invitation, TripMembership, Trip, JournalEntry, Comment, Reaction, Checklist hierarchy, and any supporting records required by the plan

### 3. Role and Permission Matrix
- Super Admin
- Contributor
- Viewer
- resource-by-resource permissions
- include controller-level authorization considerations

### 4. Trip State Machine and Allowed Transitions
- define allowed transitions between planning, started, cancelled, finished, archived
- note invalid transitions and any guard conditions
- include whether journaling/checklist behavior changes by state

### 5. Actions / Events / Subscribers / Jobs Inventory
- inventory the core Actions to implement
- list the structured events each Action should emit
- list subscribers and which workflows/jobs they should trigger
- keep the pipeline consistent with Rails.event structured events and Rails 8.1 workflows

### 6. MCP Server Boundary and Capability Surface
- define what belongs in Rails app vs MCP layer
- define what Jack can do in V1
- cover how Jack safely authors journal entries, updates checklists, comments, reactions, and trip state/details within authorization constraints
- account for Telegram idempotency and actor attribution
- do not introduce generic WhatsApp or multi-channel routing for V1

### 7. PWA Scope
- define what is in V1 for mobile-first PWA behavior
- include installability, manifest/service worker expectations, camera access, geolocation, and push notifications
- explicitly exclude offline editing/caching features unless the repo already contains them

### 8. Export Architecture
- plan Markdown and ePub generation
- explain how Action Text content and Active Storage images should be handled
- respect the exclusion of comments, reactions, and checklists
- mention PDF only as future scope if relevant

### 9. Testing Strategy
- model tests where appropriate
- action/service tests
- policy tests
- request/system tests
- workflow/event/subscriber tests
- export tests
- MCP contract/integration tests where appropriate
- include strategy for idempotency and chronology edge cases

### 10. Sequencing, Risks, and Definition of Done per Phase
Provide a phased plan with dependencies, risks, and concrete completion criteria.

At minimum include phases for:
- repository alignment / foundational setup
- access and onboarding flow
- core domain modeling
- authorization and policy enforcement
- journaling and rich text/media
- comments/reactions/checklists
- eventing and workflow orchestration
- PWA/mobile capabilities
- MCP integration with Jack
- export architecture
- hardening, testing, deployment readiness

For each phase include:
- scope
- dependencies
- risks
- definition of done

---

## 10. Planning Style Requirements

Your plan must be:
- detailed
- implementation-ready
- grounded in the actual repository
- explicit about what already exists versus what must be built
- opinionated where needed
- conservative about introducing scope

Do not write code.
Do not generate migrations.
Do not propose replacement gems or frameworks.
Do not hand-wave over repo inspection.

When you recommend architecture or sequencing, explain the rationale briefly and concretely.

# Annexes

## Design Resources

You have at your disposal a complete collection of Web UI Components and templates:

```
tree -d ~/Workspace/WebUIComponents/
~/Workspace/WebUIComponents/
├── application_ui
│   ├── application_shells
│   │   ├── multi_column
│   │   ├── sidebar
│   │   └── stacked
│   ├── data_display
│   │   ├── calendars
│   │   ├── description_lists
│   │   └── stats
│   ├── elements
│   │   ├── avatars
│   │   ├── badges
│   │   ├── button_groups
│   │   ├── buttons
│   │   └── dropdowns
│   ├── feedback
│   │   ├── alerts
│   │   └── empty_states
│   ├── forms
│   │   ├── action_panels
│   │   ├── checkboxes
│   │   ├── comboboxes
│   │   ├── form_layouts
│   │   ├── input_groups
│   │   ├── radio_groups
│   │   ├── select_menus
│   │   ├── sign_in_forms
│   │   ├── textareas
│   │   └── toggles
│   ├── headings
│   │   ├── card_headings
│   │   ├── page_headings
│   │   └── section_headings
│   ├── layout
│   │   ├── cards
│   │   ├── containers
│   │   ├── dividers
│   │   ├── list_containers
│   │   └── media_objects
│   ├── lists
│   │   ├── feeds
│   │   ├── grid_lists
│   │   ├── stacked_lists
│   │   └── tables
│   ├── navigation
│   │   ├── breadcrumbs
│   │   ├── command_palettes
│   │   ├── navbars
│   │   ├── pagination
│   │   ├── progress_bars
│   │   ├── sidebar_navigation
│   │   ├── tabs
│   │   └── vertical_navigation
│   ├── overlays
│   │   ├── drawers
│   │   ├── modal_dialogs
│   │   └── notifications
│   └── page_examples
│       ├── detail_screens
│       ├── home_screens
│       └── settings_screens
├── ecommerce
│   ├── components
│   │   ├── category_filters
│   │   ├── category_previews
│   │   ├── checkout_forms
│   │   ├── incentives
│   │   ├── order_history
│   │   ├── order_summaries
│   │   ├── product_features
│   │   ├── product_lists
│   │   ├── product_overviews
│   │   ├── product_quickviews
│   │   ├── promo_sections
│   │   ├── reviews
│   │   ├── shopping_carts
│   │   └── store_navigation
│   └── page_examples
│       ├── category_pages
│       ├── checkout_pages
│       ├── order_detail_pages
│       ├── order_history_pages
│       ├── product_pages
│       ├── shopping_cart_pages
│       └── storefront_pages
└── marketing
    ├── elements
    │   ├── banners
    │   ├── flyout_menus
    │   └── headers
    ├── feedback
    │   └── 404_pages
    ├── page_examples
    │   ├── about_pages
    │   ├── landing_pages
    │   └── pricing_pages
    └── sections
        ├── bento_grids
        ├── blog_sections
        ├── contact_sections
        ├── content_sections
        ├── cta_sections
        ├── faq_sections
        ├── feature_sections
        ├── footers
        ├── header
        ├── heroes
        ├── logo_clouds
        ├── newsletter_sections
        ├── pricing
        ├── stats_sections
        ├── team_sections
        └── testimonials

114 directories
```

Index the content, it's well organised and structured, so you know where to pick an element

Use only the HTML and CSS structure. Do not use third-party frameworks such as React, View, or any JS framework other than native Rails StimulusJS.