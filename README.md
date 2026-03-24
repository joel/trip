# Catalyst -- Trip Journal

A collaborative trip journaling web application built with Rails 8.1, Phlex components, and Hotwire.

## Architecture Overview

> Open [`docs/architecture.excalidraw`](docs/architecture.excalidraw) in [excalidraw.com](https://excalidraw.com) for the interactive diagram.

```
                        +------------------+
                        |     Browser      |
                        | (Turbo+Stimulus) |
                        +--------+---------+
                                 |
                        +--------v---------+
                        |   Rails Router   |
                        +--------+---------+
                                 |
                +----------------+----------------+
                |                                 |
       +--------v---------+              +--------v---------+
       |   Controllers    |              |    Rodauth       |
       |  (ActionPolicy)  |              |  (Auth flows)    |
       +--------+---------+              +------------------+
                |
       +--------v---------+
       |    Actions        |    Dry::Monads (Success/Failure)
       | persist + emit    |----+
       +--------+---------+    |
                |              |
       +--------v---------+   |  Rails.event.notify
       |    Models         |   |
       |  (ActiveRecord)   |   +---> +------------------+
       +------------------+         |   Subscribers    |
                                    |  (event handlers)|
                                    +--------+---------+
                                             |
                                    +--------v---------+
                                    |     Jobs         |
                                    | (Solid Queue)    |
                                    +--------+---------+
                                             |
                                    +--------v---------+
                                    |    Mailers       |
                                    +------------------+
```

## Request Lifecycle

```
  HTTP Request
       |
       v
  +---------+     +----------+     +---------+     +------------+
  | Router  |---->|Controller|---->| Action  |---->| Rails.event|
  +---------+     +----+-----+     +----+----+     +-----+------+
                       |                |                 |
                  authorize!        persist()        Subscriber
                  (ActionPolicy)    emit_event()     dispatches
                       |                |            Job
                       v                v                |
                  Phlex View       ActiveRecord      Mailer
                  (render)         (create!/update!)  (deliver)
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Rails 8.1.2, Ruby 4.0.1 |
| **Database** | SQLite with UUID primary keys (`sqlite_crypto`) |
| **Views** | Phlex 2.4 (component-based, no ERB for app views) |
| **Frontend** | Turbo, Stimulus, Tailwind CSS, Importmap |
| **Auth** | Rodauth (passwordless email auth + WebAuthn/passkeys) |
| **Authorization** | ActionPolicy |
| **Business Logic** | Dry::Monads (railway-oriented actions) |
| **Events** | Rails.event (structured events, subscriber pattern) |
| **Background Jobs** | Solid Queue |
| **Caching** | Solid Cache |
| **Real-time** | Solid Cable |
| **Storage** | Active Storage (disk dev, SeaweedFS prod) |
| **Rich Text** | Action Text |
| **Deployment** | Kamal + Docker + Thruster |

## Domain Model

```
  User
   |
   +-- has_many :trip_memberships
   |       +-- belongs_to :trip (role: contributor | viewer)
   |
   +-- has_many :trips (through: trip_memberships)
   +-- has_many :created_trips (as creator)
   +-- has_many :journal_entries (as author)
   +-- has_many :comments
   +-- has_many :reactions
   +-- has_many :exports

  Trip (state machine: planning -> started -> finished -> archived)
   |                   planning -> cancelled -> planning
   |
   +-- has_many :trip_memberships
   +-- has_many :journal_entries
   |       +-- has_rich_text :body (Action Text)
   |       +-- has_many_attached :images
   |       +-- has_many :comments
   |       +-- has_many :reactions (polymorphic)
   |
   +-- has_many :checklists
   |       +-- has_many :checklist_sections
   |               +-- has_many :checklist_items
   |
   +-- has_many :exports
   +-- has_many :reactions (polymorphic)

  Comment
   +-- has_many :reactions (polymorphic)

  Reaction (polymorphic: Trip | JournalEntry | Comment)
   +-- allowed emojis: thumbsup, heart, tada, eyes, fire, rocket
```

## Trip State Machine

```
                  +----------+
                  | planning |<---------+
                  +----+-----+          |
                       |                |
              +--------+--------+       |
              |                 |       |
         +----v-----+    +-----v----+  |
         | started  |    |cancelled |--+
         +----+-----+    +----------+
              |
         +----v-----+
         | finished |
         +----+-----+
              |
         +----v-----+
         | archived |
         +----------+
```

| State | `writable?` | `commentable?` | Transitions to |
|-------|-------------|----------------|---------------|
| planning | yes | yes | started, cancelled |
| started | yes | yes | finished, cancelled |
| finished | no | yes | archived |
| cancelled | no | no | planning |
| archived | no | no | (none) |

## Key Patterns

### Actions (Business Logic)

All business logic lives in `app/actions/` using Dry::Monads. See [`app/actions/README.md`](app/actions/README.md) for the full reference.

```ruby
result = Trips::Create.new.call(params: trip_params, user: current_user)

case result
in Dry::Monads::Success(trip)
  redirect_to trip, notice: "Trip created."
in Dry::Monads::Failure(errors)
  render Views::Trips::New.new(trip: Trip.new(trip_params)),
         status: :unprocessable_content
end
```

### Event-Driven Subscribers

Actions emit events via `Rails.event.notify`. Subscribers react and dispatch jobs.

```
Action emits event  -->  Subscriber receives  -->  Job executes
"export.requested"       ExportSubscriber          GenerateExportJob
"trip.state_changed"     TripSubscriber             NotifyTripStateChangeJob
"invitation.sent"        InvitationSubscriber       SendInvitationEmailJob
```

### Phlex Views

All views are Ruby classes. No ERB for application views.

```ruby
module Views
  module Trips
    class Show < Views::Base
      def initialize(trip:, journal_entries:)
        @trip = trip
        @journal_entries = journal_entries
      end

      def view_template
        div(class: "space-y-8") do
          render Components::PageHeader.new(section: "Trips", title: @trip.name)
          render_journal_entries
        end
      end
    end
  end
end
```

## Setup

### Prerequisites

- Docker and Docker Compose
- Ruby 4.0.1 (via mise, rbenv, or similar)

### Quick Start

```bash
git clone git@github.com:joel/trip.git && cd trip
bin/cli services start dev     # Start all services
bin/cli db reset dev           # Reset DB with seed data
open https://catalyst.workeverywhere.docker
```

Login as `joel@acme.org` (superadmin) via email auth.

### CLI Commands

```bash
bin/cli app start|stop|rebuild|restart|logs [dev|prod]
bin/cli db reset|start|stop|console [dev|prod]
bin/cli mail start
bin/cli services start|stop [dev|prod]
bin/cli tree                     # Show all commands
```

### URLs

| Service | URL |
|---------|-----|
| Application | https://catalyst.workeverywhere.docker |
| MailCatcher | https://mail.workeverywhere.docker |

### Seed Data

The seed (`db/seeds.rb`) creates a complete dataset for development:

- **6 users** -- 1 superadmin, 3 contributors, 2 viewers
- **5 trips** -- one per state (planning, started, finished, cancelled, archived)
- **11 journal entries** -- with rich text, locations, and images from picsum.photos
- **12 comments**, **25 reactions** (all 6 emoji types)
- **3 checklists** -- various completion states
- **3 access requests** -- pending, approved, rejected
- **3 invitations** -- pending, accepted, expired
- **3 exports** -- completed (with file), pending, failed

## Development

### Tests

```bash
mise x -- bundle exec rake                        # Everything
mise x -- bundle exec rake project:tests           # Unit + request specs
mise x -- bundle exec rake project:system-tests    # System tests
mise x -- bundle exec rake project:lint            # RuboCop + ERB lint
mise x -- bundle exec rake project:fix-lint        # Auto-fix
```

### Git Hooks (overcommit)

- **RuboCop** -- style + lint
- **TrailingWhitespace** -- no trailing spaces
- **FixMe** -- no FIXME tokens
- **BundleCheck** -- Gemfile.lock in sync

### Project Structure

```
app/
  actions/         # Business logic (Dry::Monads) -- see AGENTS.md
  components/      # Phlex components (cards, badges, sidebar, forms)
  controllers/     # Thin controllers (delegate to actions)
  jobs/            # Background jobs (Solid Queue)
  mailers/         # Email delivery
  models/          # ActiveRecord models
  policies/        # ActionPolicy authorization
  services/        # Domain services (export generators)
  subscribers/     # Rails.event subscribers
  views/           # Phlex page views
config/
  initializers/
    event_subscribers.rb  # Subscriber registry
    roles.rb              # Role definitions
```
