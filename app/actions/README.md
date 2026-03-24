# Actions

Business logic layer for the application. Each action encapsulates a single domain operation using [Dry::Monads](https://dry-rb.org/gems/dry-monads/) for result handling and [Rails.event](https://guides.rubyonrails.org/active_support_instrumentation.html) for event emission.

## Why Actions?

Controllers stay thin. Models stay persistence-focused. Actions own the business logic:

- **Testable** -- plain Ruby objects, no HTTP context needed
- **Composable** -- monadic `yield` chains steps, short-circuits on failure
- **Observable** -- every mutation emits a structured event for downstream subscribers

## How It Works

```ruby
# 1. Controller calls the action
result = Trips::Create.new.call(params: trip_params, user: current_user)

# 2. Pattern-match on the result
case result
in Dry::Monads::Success(trip)
  redirect_to trip, notice: "Trip created."
in Dry::Monads::Failure(errors)
  render Views::Trips::New.new(trip: Trip.new), status: :unprocessable_content
end
```

Inside the action:

```ruby
module Trips
  class Create < BaseAction
    def call(params:, user:)
      trip = yield persist(params, user)   # fails fast if invalid
      yield emit_event(trip)               # notifies subscribers
      Success(trip)
    end

    private

    def persist(params, user)
      Success(Trip.create!(params.merge(created_by: user)))
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(trip)
      Rails.event.notify("trip.created", trip_id: trip.id)
      Success()
    end
  end
end
```

## Actions Inventory

| Domain | Action | What it does |
|--------|--------|-------------|
| **Trips** | `Create` | Create a trip |
| | `Update` | Update trip attributes |
| | `TransitionState` | Move trip between states with guard validation |
| **Journal Entries** | `Create` | Add an entry to a trip |
| | `Update` | Edit an entry |
| | `Delete` | Remove an entry |
| **Comments** | `Create` | Add a comment to an entry |
| | `Update` | Edit a comment |
| | `Delete` | Remove a comment |
| **Reactions** | `Toggle` | Add or remove an emoji reaction (idempotent) |
| **Exports** | `RequestExport` | Request a Markdown or ePub export |
| **Access Requests** | `Submit` | Submit a public access request |
| | `Approve` | Admin approves a request |
| | `Reject` | Admin rejects a request |
| **Invitations** | `SendInvitation` | Send an invitation email |
| | `Accept` | Accept an invitation token |
| **Trip Memberships** | `Assign` | Add a member to a trip |
| | `Remove` | Remove a member |
| **Checklists** | `Create` / `Update` / `Delete` | Manage checklists |
| **Checklist Items** | `Create` | Add an item to a section |
| | `Toggle` | Toggle item completion |

## Patterns

**Standard CRUD**: `persist() -> emit_event() -> Success(record)`

**Delete with ID capture**: Capture IDs before `destroy!` since the object is gone after.

**Guard validation**: Check business rules (e.g., trip must have members) before allowing state transitions.

**Idempotent toggle**: Find-or-remove pattern for reactions -- no `yield`, uses conditional branching.

**Pre-validation**: Check preconditions (e.g., no duplicate pending exports) before persisting.

## Events

Every action emits a structured event via `Rails.event.notify("entity.action", payload)`. Subscribers in `app/subscribers/` listen for these events and dispatch background jobs (emails, image processing, etc).

See `config/initializers/event_subscribers.rb` for the subscriber registry.

## For AI Agents

See [`AGENTS.md`](AGENTS.md) for the full technical reference including event payloads, error conventions, and implementation templates.
