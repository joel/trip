# Actions

Business logic layer for the application. Each action encapsulates a single domain operation using [Dry::Monads](https://dry-rb.org/gems/dry-monads/) for result handling and [Rails.event](https://guides.rubyonrails.org/active_support_instrumentation.html) for event emission.

## Why Actions?

Controllers stay thin. Models stay persistence-focused. Actions own the business logic:

- **Testable** -- plain Ruby objects, no HTTP context needed
- **Composable** -- monadic `yield` chains steps, short-circuits on failure
- **Observable** -- every mutation emits a structured event for downstream subscribers

## The Big Picture

```
                    +------------------------------+
                    |        HTTP Request           |
                    +-------------+----------------+
                                  |
                                  v
+----------+            +-----------------+            +-------------+
|          |  authorize |                 |   call()   |             |
|  Policy  |<-----------+   Controller    +----------->|   Action    |
|          |            |                 |            |             |
+----------+            +--------+--------+            +------+------+
                                 |                            |
                            render                     +------+------+
                                 |                     |             |
                                 v                     |  persist()  |
                        +-----------------+            |  emit()     |
                        |   Phlex View    |            |             |
                        +-----------------+            +------+------+
                                                              |
                                            Rails.event.notify|
                                                              v
                                                    +---------+--------+
                                                    |    Subscriber    |
                                                    +--------+---------+
                                                             |
                                                   perform_later
                                                             v
                                                    +---------+--------+
                                                    |   Background     |
                                                    |      Job         |
                                                    +--------+---------+
                                                             |
                                                             v
                                                    +---------+--------+
                                                    |     Mailer       |
                                                    +------------------+
```

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

## The Railway: Success & Failure

Actions use the **railway pattern** -- data flows along the "happy track" until something fails, then it switches to the "error track" and skips remaining steps:

```
  call()
    |
    v
 persist()  --Success--> emit_event()  --Success--> return Success(record)
    |                        |
    |                        |
  Failure                  Failure
    |                        |
    +--------+---------------+
             |
             v
      return Failure(errors)   <-- controller renders error page
```

The `yield` keyword unwraps `Success` values and short-circuits on `Failure` -- no nested `if/else` chains needed.

## Patterns at a Glance

### Standard Create/Update

```
call(params:) --> persist() --> emit_event() --> Success(record)
```

### Delete (capture IDs first)

```
capture ids --> destroy!() --> emit_event(ids) --> Success()

Why: the record is gone after destroy!, so grab IDs before.
```

### Guard + State Transition

```
validate_guard() --> capture from_state --> transition!() --> emit_event() --> Success()
      |
      +-- Failure(:requires_members)

Example: can't start a trip without members.
```

### Idempotent Toggle

```
find existing reaction
  |
  +-- found?    --> remove() --> Success(:removed)
  +-- not found --> add()    --> Success(reaction)
```

### Pre-validation

```
check_precondition() --> persist() --> emit_event() --> Success(record)
        |
        +-- Failure("already in progress")

Example: one pending export per user/trip/format.
```

## Event Flow

Every action emits events. Subscribers react. Jobs execute. It's a clean pipeline:

```
  +------------------+         +-------------------+         +------------------+
  |     Action       |         |    Subscriber     |         |      Job         |
  |                  |         |                   |         |                  |
  | "trip.created"   +-------->| TripSubscriber    +-------->| (log only)       |
  |                  |         |                   |         |                  |
  | "export.         +-------->| ExportSubscriber  +-------->| GenerateExport   |
  |  requested"      |         |                   |         |   Job            |
  |                  |         |                   |         |                  |
  | "trip.state_     +-------->| TripSubscriber    +-------->| NotifyTrip       |
  |  changed"        |         |                   |         |  StateChangeJob  |
  |                  |         |                   |         |                  |
  | "invitation.     +-------->| InvitationSub     +-------->| SendInvitation   |
  |  sent"           |         |                   |         |  EmailJob        |
  |                  |         |                   |         |                  |
  | "journal_entry.  +-------->| JournalEntrySub   +-------->| ProcessJournal   |
  |  created"        |         |                   |         |  ImagesJob       |
  +------------------+         +-------------------+         +------------------+
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

## Error Handling

Actions return typed failures that controllers can pattern-match on:

```
+-----------------------------+------------------------------------------+
| Scenario                    | What the action returns                  |
+-----------------------------+------------------------------------------+
| Validation failure          | Failure(e.record.errors)                 |
| Business rule violated      | Failure(:requires_members)               |
| Record not found            | Failure(:not_found)                      |
| Invalid enum value          | Failure(errors) with errors.add(:format) |
+-----------------------------+------------------------------------------+
                                       |
                                       v
                              Controller pattern-matches:
                              in Failure(:requires_members) -> alert
                              in Failure(errors)            -> render form
```

## Directory Structure

```
app/actions/
  base_action.rb               <-- includes Dry::Monads
  access_requests/
    approve.rb, reject.rb, submit.rb
  checklist_items/
    create.rb, toggle.rb
  checklists/
    create.rb, delete.rb, update.rb
  comments/
    create.rb, delete.rb, update.rb
  exports/
    request_export.rb
  invitations/
    accept.rb, send_invitation.rb
  journal_entries/
    create.rb, delete.rb, update.rb
  reactions/
    toggle.rb
  trip_memberships/
    assign.rb, remove.rb
  trips/
    create.rb, transition_state.rb, update.rb
```

## For AI Agents

See [`AGENTS.md`](AGENTS.md) for the full technical reference including event payloads, error conventions, and implementation templates.
