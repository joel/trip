# Actions Pattern

This directory contains all business logic actions for the application. Actions encapsulate domain operations using **Dry::Monads** for composable, railway-oriented flow control with **Rails.event** for structured event emission.

## Architecture

```
Controller                  Action                    Subscriber
    |                         |                          |
    |  call(params:, user:)   |                          |
    |------------------------>|                          |
    |                         |  persist()               |
    |                         |  emit_event()            |
    |                         |     |                    |
    |                         |     | Rails.event.notify |
    |                         |     |  "entity.action"   |
    |                         |     |------------------->|
    |                         |                          | Job.perform_later
    |  Success(record)        |                          |
    |<------------------------|                          |
    |                         |                          |
    |  case result            |                          |
    |  in Success(v) -> redirect                         |
    |  in Failure(e) -> render errors                    |
```

## Base Class

All actions inherit from `BaseAction` which includes `Dry::Monads[:result, :do]`:

```ruby
# app/actions/base_action.rb
class BaseAction
  include Dry::Monads[:result, :do]
end
```

This provides:
- `Success(value)` — wrap a successful result
- `Failure(value)` — wrap a failure result
- `yield` — unwrap a `Success` or short-circuit on `Failure`

## Standard Action Template

```ruby
module Trips
  class Create < BaseAction
    def call(params:, user:)
      trip = yield persist(params, user)    # Step 1: persist
      yield emit_event(trip)                # Step 2: emit event
      Success(trip)                         # Step 3: return
    end

    private

    def persist(params, user)
      trip = Trip.create!(params.merge(created_by: user))
      Success(trip)
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

## Flow Patterns

### Create / Update

```
call(params:, ...) -> persist() -> emit_event() -> Success(record)
```

### Delete (ID capture)

Capture IDs before `destroy!` because the object becomes unqueryable after:

```ruby
def call(journal_entry:)
  entry_id = journal_entry.id
  trip_id = journal_entry.trip_id
  yield destroy(journal_entry)
  yield emit_event(entry_id, trip_id)
  Success()
end
```

### Guard + Transition

Validate business rules before allowing state changes:

```ruby
def call(trip:, new_state:)
  yield validate_guard(trip, new_state)   # e.g., must have members
  from_state = trip.state
  yield transition(trip, new_state)
  yield emit_event(trip, from_state)
  Success(trip)
end
```

### Toggle (idempotent)

Branch without `yield` for create-or-remove patterns:

```ruby
def call(reactable:, user:, emoji:)
  existing = reactable.reactions.find_by(user: user, emoji: emoji)
  if existing
    remove(existing)      # -> Success(:removed)
  else
    add(reactable, ...)   # -> Success(reaction)
  end
end
```

### Pre-validation

Check preconditions before persisting:

```ruby
def call(trip:, user:, format:)
  yield check_no_active_export(trip, user, format)
  export = yield persist(trip, user, format)
  yield emit_event(export)
  Success(export)
end
```

## Controller Integration

Controllers use pattern matching on the result:

```ruby
result = Trips::Create.new.call(params: trip_params, user: current_user)

case result
in Dry::Monads::Success(trip)
  redirect_to trip, notice: "Trip created."
in Dry::Monads::Failure(:requires_members)
  redirect_to @trip, alert: "Add at least one member."
in Dry::Monads::Failure(errors)
  @trip = Trip.new(trip_params)
  @trip.errors.merge!(errors)
  render Views::Trips::New.new(trip: @trip), status: :unprocessable_content
end
```

## Error Handling Conventions

| Scenario | Return Value |
|----------|-------------|
| Validation failure | `Failure(e.record.errors)` — ActiveModel::Errors |
| Business rule violation | `Failure(:atom_symbol)` — e.g., `:requires_members` |
| Not found | `Failure(:not_found)` |
| Invalid enum value | `Failure(custom_errors)` with `errors.add(:field, :invalid)` |
| Generic message | `Failure(message_string)` |

## Event Naming Convention

Events follow the pattern `entity.action`:

| Event | Emitted By | Payload |
|-------|-----------|---------|
| `trip.created` | Trips::Create | `{ trip_id }` |
| `trip.updated` | Trips::Update | `{ trip_id }` |
| `trip.state_changed` | Trips::TransitionState | `{ trip_id, from_state, to_state }` |
| `journal_entry.created` | JournalEntries::Create | `{ journal_entry_id, trip_id, actor_id }` |
| `journal_entry.updated` | JournalEntries::Update | `{ journal_entry_id, trip_id }` |
| `journal_entry.deleted` | JournalEntries::Delete | `{ journal_entry_id, trip_id }` |
| `comment.created` | Comments::Create | `{ comment_id, journal_entry_id, actor_id }` |
| `comment.updated` | Comments::Update | `{ comment_id, journal_entry_id }` |
| `comment.deleted` | Comments::Delete | `{ comment_id, journal_entry_id }` |
| `reaction.created` | Reactions::Toggle | `{ reaction_id, reactable_type, reactable_id }` |
| `reaction.removed` | Reactions::Toggle | `{ reaction_id, reactable_type, reactable_id }` |
| `export.requested` | Exports::RequestExport | `{ export_id, trip_id, user_id, format }` |
| `access_request.submitted` | AccessRequests::Submit | `{ access_request_id, email }` |
| `access_request.approved` | AccessRequests::Approve | `{ access_request_id, email, reviewer_id }` |
| `access_request.rejected` | AccessRequests::Reject | `{ access_request_id, email }` |
| `invitation.sent` | Invitations::SendInvitation | `{ invitation_id, email }` |
| `invitation.accepted` | Invitations::Accept | `{ invitation_id, email }` |
| `trip_membership.created` | TripMemberships::Assign | `{ trip_membership_id, trip_id, user_id, actor_id }` |
| `trip_membership.removed` | TripMemberships::Remove | `{ trip_membership_id, trip_id, user_id }` |
| `checklist.created` | Checklists::Create | `{ checklist_id, trip_id }` |
| `checklist.updated` | Checklists::Update | `{ checklist_id, trip_id }` |
| `checklist.deleted` | Checklists::Delete | `{ checklist_id, trip_id }` |
| `checklist_item.created` | ChecklistItems::Create | `{ checklist_item_id, checklist_id }` |
| `checklist_item.toggled` | ChecklistItems::Toggle | `{ checklist_item_id, checklist_id }` |

## Adding a New Action

1. Create `app/actions/<domain>/<verb>.rb`
2. Inherit from `BaseAction`
3. Implement `call(...)` with named parameters
4. Use `yield` to chain `persist` + `emit_event` steps
5. Emit a `domain.verb` event via `Rails.event.notify`
6. Register a subscriber in `config/initializers/event_subscribers.rb` if needed
7. Call from the controller using `ActionClass.new.call(...)`
8. Pattern-match on `Success` / `Failure` in the controller

## Directory Structure

```
app/actions/
  base_action.rb
  access_requests/
    approve.rb
    reject.rb
    submit.rb
  checklist_items/
    create.rb
    toggle.rb
  checklists/
    create.rb
    delete.rb
    update.rb
  comments/
    create.rb
    delete.rb
    update.rb
  exports/
    request_export.rb
  invitations/
    accept.rb
    send_invitation.rb
  journal_entries/
    create.rb
    delete.rb
    update.rb
  reactions/
    toggle.rb
  trip_memberships/
    assign.rb
    remove.rb
  trips/
    create.rb
    transition_state.rb
    update.rb
```
