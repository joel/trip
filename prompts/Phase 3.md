# Phase 3: Core Domain Modeling

## Context

Phase 2 built the invite-only access system. Phase 3 builds the core trip journal domain: Trip (with state machine), TripMembership (user-trip join with roles), and JournalEntry (with Action Text rich body, Active Storage images, and chronological ordering). This is the heart of the application.

## User Decisions

- **Authorization:** Deferred to Phase 4. Controllers use `require_authenticated_user!` only, no `authorize!` calls.
- **Trip creation:** Superadmin only (per PRP).
- **Rich text:** Action Text with Trix editor (already installed in Phase 1).

---

## Scope

### Models & Migrations
1. **Trip** — name, description, state machine, metadata JSON, start/end dates, created_by
2. **TripMembership** — trip-user join with contributor/viewer role
3. **JournalEntry** — trip-scoped, author, entry_date, location, Action Text body, Active Storage images, Telegram idempotency fields

### Actions (Dry::Monads)
4. **Trips::Create** — create trip, emit `trip.created`
5. **Trips::Update** — update trip details, emit `trip.updated`
6. **Trips::TransitionState** — validate and apply state transitions, emit `trip.state_changed`
7. **JournalEntries::Create** — create entry with body/images, emit `journal_entry.created`
8. **JournalEntries::Update** — update entry, emit `journal_entry.updated`
9. **JournalEntries::Delete** — delete entry, emit `journal_entry.deleted`
10. **TripMemberships::Assign** — add user to trip, emit `trip_membership.created`
11. **TripMemberships::Remove** — remove user from trip, emit `trip_membership.removed`

### Controllers & Views
12. **TripsController** — full CRUD + state transitions
13. **JournalEntriesController** — nested under trips, CRUD
14. **TripMembershipsController** — nested under trips, create/destroy

### Components (Phlex)
15. Trip card, form, state badge, timeline header
16. Journal entry card, form (with Trix editor + image upload)
17. Trip membership card, form (user select + role)

### Sidebar & Navigation
18. Add "Trips" nav item for authenticated users

### Events
19. Wire all actions to emit structured events, register subscribers

---

## Files to Create

### Migrations
- `db/migrate/TIMESTAMP_create_trips.rb`
- `db/migrate/TIMESTAMP_create_trip_memberships.rb`
- `db/migrate/TIMESTAMP_create_journal_entries.rb`

### Models
- `app/models/trip.rb`
- `app/models/trip_membership.rb`
- `app/models/journal_entry.rb`
- `app/models/concerns/state_machine.rb` (extracted for reuse)

### Actions
- `app/actions/trips/create.rb`
- `app/actions/trips/update.rb`
- `app/actions/trips/transition_state.rb`
- `app/actions/journal_entries/create.rb`
- `app/actions/journal_entries/update.rb`
- `app/actions/journal_entries/delete.rb`
- `app/actions/trip_memberships/assign.rb`
- `app/actions/trip_memberships/remove.rb`

### Controllers
- `app/controllers/trips_controller.rb`
- `app/controllers/journal_entries_controller.rb`
- `app/controllers/trip_memberships_controller.rb`

### Views (Phlex)
- `app/views/trips/index.rb`
- `app/views/trips/show.rb`
- `app/views/trips/new.rb`
- `app/views/trips/edit.rb`
- `app/views/journal_entries/show.rb`
- `app/views/journal_entries/new.rb`
- `app/views/journal_entries/edit.rb`
- `app/views/trip_memberships/index.rb`
- `app/views/trip_memberships/new.rb`

### Components (Phlex)
- `app/components/trip_card.rb`
- `app/components/trip_form.rb`
- `app/components/trip_state_badge.rb`
- `app/components/journal_entry_card.rb`
- `app/components/journal_entry_form.rb`
- `app/components/trip_membership_card.rb`
- `app/components/trip_membership_form.rb`

### Subscribers & Jobs
- `app/subscribers/trip_subscriber.rb`
- `app/subscribers/journal_entry_subscriber.rb`
- `app/subscribers/trip_membership_subscriber.rb`
- `app/jobs/send_trip_assignment_email_job.rb`
- `app/mailers/trip_mailer.rb`
- `app/views/trip_mailer/member_added.text.erb`

### Factories & Specs
- `spec/factories/trips.rb`
- `spec/factories/trip_memberships.rb`
- `spec/factories/journal_entries.rb`
- `spec/models/trip_spec.rb`
- `spec/models/trip_membership_spec.rb`
- `spec/models/journal_entry_spec.rb`
- `spec/actions/trips/create_spec.rb`
- `spec/actions/trips/transition_state_spec.rb`
- `spec/actions/journal_entries/create_spec.rb`
- `spec/actions/trip_memberships/assign_spec.rb`
- `spec/requests/trips_spec.rb`
- `spec/requests/journal_entries_spec.rb`
- `spec/requests/trip_memberships_spec.rb`
- `spec/system/trips_spec.rb`
- `spec/system/journal_entries_spec.rb`

### Files to Modify
- `config/routes.rb` — trips, nested journal_entries, nested trip_memberships
- `config/initializers/event_subscribers.rb` — register new subscribers
- `app/components/sidebar.rb` — add Trips nav item
- `app/models/user.rb` — add has_many :trip_memberships, :trips associations
- `db/seeds.rb` — seed a sample trip

---

## Implementation Details

### 1. Trip Model

```ruby
class Trip < ApplicationRecord
  VALID_TRANSITIONS = {
    planning: %i[started cancelled],
    started: %i[finished cancelled],
    finished: %i[archived],
    cancelled: %i[planning],
    archived: []
  }.freeze

  class InvalidTransitionError < StandardError; end

  enum :state, { planning: 0, started: 1, cancelled: 2, finished: 3, archived: 4 }

  belongs_to :created_by, class_name: "User"
  has_many :trip_memberships, dependent: :destroy
  has_many :members, through: :trip_memberships, source: :user
  has_many :journal_entries, dependent: :destroy

  validates :name, presence: true

  def transition_to!(new_state)
    new_state = new_state.to_sym
    unless VALID_TRANSITIONS[state.to_sym]&.include?(new_state)
      raise InvalidTransitionError,
        "Cannot transition from #{state} to #{new_state}"
    end
    update!(state: new_state)
  end

  def can_transition_to?(new_state)
    VALID_TRANSITIONS[state.to_sym]&.include?(new_state.to_sym) || false
  end

  # Writable content allowed in planning and started states
  def writable?
    planning? || started?
  end

  # Derived dates
  def effective_start_date
    start_date || journal_entries.chronological.first&.entry_date
  end

  def effective_end_date
    end_date || journal_entries.chronological.last&.entry_date
  end

  # Derived locations
  def start_location
    journal_entries.chronological.where.not(location_name: nil).first
  end

  def end_location
    journal_entries.chronological.where.not(location_name: nil).last
  end
end
```

### 2. TripMembership Model

```ruby
class TripMembership < ApplicationRecord
  enum :role, { contributor: 0, viewer: 1 }

  belongs_to :trip
  belongs_to :user

  validates :user_id, uniqueness: { scope: :trip_id }
end
```

### 3. JournalEntry Model

```ruby
class JournalEntry < ApplicationRecord
  belongs_to :trip
  belongs_to :author, class_name: "User"

  has_rich_text :body
  has_many_attached :images

  validates :name, presence: true
  validates :entry_date, presence: true

  scope :chronological, -> {
    order(entry_date: :asc, created_at: :asc, id: :asc)
  }
end
```

### 4. Trip Migration

```ruby
create_table :trips, id: :uuid do |t|
  t.string :name, null: false
  t.text :description
  t.integer :state, null: false, default: 0
  t.json :metadata, null: false, default: "{}"
  t.date :start_date
  t.date :end_date
  t.references :created_by, type: :uuid, null: false, foreign_key: { to_table: :users }
  t.timestamps
end
```

### 5. JournalEntry Migration

```ruby
create_table :journal_entries, id: :uuid do |t|
  t.references :trip, type: :uuid, null: false, foreign_key: true
  t.references :author, type: :uuid, null: false, foreign_key: { to_table: :users }
  t.string :name, null: false
  t.text :description
  t.date :entry_date, null: false
  t.string :location_name
  t.decimal :latitude, precision: 10, scale: 7
  t.decimal :longitude, precision: 10, scale: 7
  t.string :actor_type
  t.string :actor_id
  t.string :telegram_message_id
  t.string :telegram_chat_id
  t.timestamps
end

add_index :journal_entries, [:trip_id, :entry_date, :created_at, :id],
          name: "idx_journal_entries_chronological"
add_index :journal_entries, :telegram_message_id
```

### 6. Routes

```ruby
resources :trips do
  resources :journal_entries, except: [:index]
  resources :trip_memberships, only: %i[index new create destroy], path: "members"
  member do
    patch :transition
  end
end
```

Journal entries index is the trip show page (entries listed there). Individual entry show/new/edit/destroy are nested.

### 7. TripsController

```ruby
class TripsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip, only: %i[show edit update destroy transition]

  def index
    @trips = current_user.role?(:superadmin) ? Trip.all : current_user.trips
    render Views::Trips::Index.new(trips: @trips.order(created_at: :desc))
  end

  def show
    @journal_entries = @trip.journal_entries.chronological
    render Views::Trips::Show.new(trip: @trip, journal_entries: @journal_entries)
  end

  def new
    @trip = Trip.new
    render Views::Trips::New.new(trip: @trip)
  end

  def create
    result = Trips::Create.new.call(params: trip_params, user: current_user)
    case result
    in Dry::Monads::Success(trip)
      redirect_to trip, notice: "Trip created."
    in Dry::Monads::Failure(errors)
      @trip = Trip.new(trip_params)
      @trip.errors.merge!(errors) if errors.respond_to?(:each)
      render Views::Trips::New.new(trip: @trip), status: :unprocessable_content
    end
  end

  # ...update, destroy, transition actions

  private

  def set_trip
    @trip = Trip.find(params[:id])
  end

  def trip_params
    params.expect(trip: [:name, :description, :start_date, :end_date])
  end
end
```

### 8. JournalEntriesController (nested)

```ruby
class JournalEntriesController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip
  before_action :set_journal_entry, only: %i[show edit update destroy]

  def show
    render Views::JournalEntries::Show.new(trip: @trip, journal_entry: @journal_entry)
  end

  def new
    @journal_entry = @trip.journal_entries.new(entry_date: Date.current)
    render Views::JournalEntries::New.new(trip: @trip, journal_entry: @journal_entry)
  end

  def create
    result = JournalEntries::Create.new.call(
      params: journal_entry_params, trip: @trip, user: current_user
    )
    case result
    in Dry::Monads::Success(entry)
      redirect_to [@trip, entry], notice: "Entry created."
    in Dry::Monads::Failure(errors)
      @journal_entry = @trip.journal_entries.new(journal_entry_params)
      @journal_entry.errors.merge!(errors) if errors.respond_to?(:each)
      render Views::JournalEntries::New.new(trip: @trip, journal_entry: @journal_entry),
             status: :unprocessable_content
    end
  end

  # ...edit, update, destroy

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def set_journal_entry
    @journal_entry = @trip.journal_entries.find(params[:id])
  end

  def journal_entry_params
    params.expect(journal_entry: [:name, :description, :entry_date,
                                  :location_name, :latitude, :longitude,
                                  :body, images: []])
  end
end
```

### 9. TripMembershipsController

```ruby
class TripMembershipsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip

  def index
    @memberships = @trip.trip_memberships.includes(:user)
    render Views::TripMemberships::Index.new(trip: @trip, memberships: @memberships)
  end

  def new
    @membership = @trip.trip_memberships.new
    render Views::TripMemberships::New.new(trip: @trip, membership: @membership)
  end

  def create
    result = TripMemberships::Assign.new.call(
      params: membership_params, trip: @trip
    )
    case result
    in Dry::Monads::Success
      redirect_to trip_trip_memberships_path(@trip), notice: "Member added."
    in Dry::Monads::Failure(errors)
      @membership = @trip.trip_memberships.new(membership_params)
      @membership.errors.merge!(errors) if errors.respond_to?(:each)
      render Views::TripMemberships::New.new(trip: @trip, membership: @membership),
             status: :unprocessable_content
    end
  end

  def destroy
    membership = @trip.trip_memberships.find(params[:id])
    TripMemberships::Remove.new.call(membership: membership)
    redirect_to trip_trip_memberships_path(@trip), notice: "Member removed."
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def membership_params
    params.expect(trip_membership: [:user_id, :role])
  end
end
```

### 10. Sidebar Update

Add "Trips" nav item for authenticated users after "Overview":

```ruby
if view_context.rodauth.logged_in?
  render Components::NavItem.new(
    path: view_context.trips_path,
    label: "Trips",
    icon: Components::Icons::Home.new, # reuse existing icon
    active: %w[trips journal_entries trip_memberships].include?(view_context.controller_name),
    delay: "80ms"
  )
end
```

### 11. User Model Associations

Add to `app/models/user.rb`:
```ruby
has_many :trip_memberships, dependent: :destroy
has_many :trips, through: :trip_memberships
has_many :created_trips, class_name: "Trip", foreign_key: :created_by_id, dependent: :nullify
has_many :journal_entries, foreign_key: :author_id, dependent: :nullify
```

---

## Key Design Notes

### Chronological Ordering
Journal entries ordered by: `entry_date ASC, created_at ASC, id ASC`. This means retroactive entries (created later but with earlier entry_date) appear in correct chronological position.

### Derived Dates & Locations
- `Trip#effective_start_date`: explicit `start_date` if set, otherwise earliest entry's `entry_date`
- `Trip#effective_end_date`: explicit `end_date` if set, otherwise latest entry's `entry_date`
- `Trip#start_location`: first chronological entry with non-nil `location_name`
- `Trip#end_location`: last chronological entry with non-nil `location_name`

### State Machine Guards
- `planning → started`: requires at least one trip membership
- All others: no guards
- `archived`: terminal state, no transitions out

### Action Text Integration
JournalEntry uses `has_rich_text :body` with Trix editor in forms. The form field is `form.rich_text_area :body`. Images can be embedded via Trix or uploaded separately via `has_many_attached :images`.

---

## Verification

### Automated Tests
```bash
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
mise x -- bundle exec rake project:lint
```

### Runtime Test Checklist
- [ ] `/trips` renders trip list (empty state for new users)
- [ ] Superadmin can create a trip at `/trips/new`
- [ ] Trip show page displays details and empty journal entries
- [ ] State transitions work (planning → started → finished)
- [ ] Invalid state transitions are rejected
- [ ] Journal entry can be created with rich text body
- [ ] Journal entries display in chronological order by entry_date
- [ ] Retroactive entry (earlier date, created later) appears in correct position
- [ ] Images can be attached to journal entries
- [ ] Trip membership: superadmin can add/remove users
- [ ] Derived trip dates reflect journal entry dates
- [ ] Sidebar shows "Trips" link for authenticated users
- [ ] Dark mode works on all new pages
- [ ] No runtime errors

### Definition of Done (from PRP)
- [ ] Trip CRUD works with all states
- [ ] State machine enforces valid transitions
- [ ] Journal entries display in canonical chronological order
- [ ] Retroactive entries correctly reorder timeline
- [ ] Derived trip dates and locations calculate correctly
- [ ] Images upload and display via Active Storage
- [ ] Rich text editing works via Action Text
- [ ] Trip membership assignment works
- [ ] All model validations and scopes tested
- [ ] Request and system tests pass
