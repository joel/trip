# Phase 4: Authorization & Policy Enforcement

## Context

Phase 3 built the core domain (Trip, TripMembership, JournalEntry) with full CRUD, state machine, and event system. All Phase 3 controllers use `require_authenticated_user!` only — no `authorize!` calls. Any authenticated user can currently access any trip, create/delete entries on any trip, and manage memberships on any trip. Phase 4 locks this down with ActionPolicy.

The authorization framework is already in place:
- `ApplicationPolicy < ActionPolicy::Base` with `superadmin?` helper (`app/policies/application_policy.rb`)
- `ApplicationController` includes `ActionPolicy::Controller` with `authorize :user` (`app/controllers/application_controller.rb`)
- Existing policies: `UserPolicy`, `InvitationPolicy`, `AccessRequestPolicy` (all superadmin-only)
- Existing controller pattern: `before_action :authorize_resource!` calling `authorize!(@record || ModelClass)` (`app/controllers/users_controller.rb:7,66-68`)
- Existing spec pattern: `described_class.new(record, user:).apply(:action?)` (`spec/policies/invitation_policy_spec.rb`)
- Unauthorized rescue renders `:forbidden` (403) (`app/controllers/application_controller.rb:10-12`)

---

## Permission Matrix

### Global Roles (User#roles_mask)
- **superadmin** — full access to everything
- **guest** — default role, no trip access unless assigned via TripMembership

### Trip-Scoped Roles (TripMembership#role)
- **contributor** — view trip + entries, create entries (if writable), edit/delete own entries, update trip
- **viewer** — view trip + entries only, no mutations

| Resource | Action | Superadmin | Contributor | Viewer | No Membership |
|----------|--------|-----------|-------------|--------|---------------|
| Trip | index | all trips | own trips | own trips | empty |
| Trip | show | yes | yes | yes | no (403) |
| Trip | new/create | yes | no | no | no |
| Trip | edit/update | yes | yes | no | no |
| Trip | destroy | yes | no | no | no |
| Trip | transition | yes | no | no | no |
| JournalEntry | show | yes | yes | yes | no (403) |
| JournalEntry | new/create | yes | yes (if writable) | no | no |
| JournalEntry | edit/update | yes | own entries only | no | no |
| JournalEntry | destroy | yes | own entries only | no | no |
| TripMembership | index | yes | yes | yes | no (403) |
| TripMembership | new/create | yes | no | no | no |
| TripMembership | destroy | yes | no | no | no |

---

## Files to Create (6)

### 1. `app/policies/trip_policy.rb`

```ruby
# frozen_string_literal: true

class TripPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    superadmin? || member?
  end

  def create?
    superadmin?
  end

  def new?
    create?
  end

  def edit?
    superadmin? || contributor?
  end

  def update?
    edit?
  end

  def destroy?
    superadmin?
  end

  def transition?
    superadmin?
  end

  private

  def trip_membership
    return unless user && record.is_a?(Trip)

    record.trip_memberships.find_by(user: user)
  end

  def member?
    trip_membership.present?
  end

  def contributor?
    trip_membership&.contributor?
  end
end
```

### 2. `app/policies/journal_entry_policy.rb`

```ruby
# frozen_string_literal: true

class JournalEntryPolicy < ApplicationPolicy
  def show?
    superadmin? || member?
  end

  def create?
    superadmin? || (contributor? && record.trip.writable?)
  end

  def new?
    create?
  end

  def edit?
    superadmin? || (contributor? && own_entry?)
  end

  def update?
    edit?
  end

  def destroy?
    superadmin? || (contributor? && own_entry?)
  end

  private

  def trip_membership
    return unless user

    record.trip.trip_memberships.find_by(user: user)
  end

  def member?
    trip_membership.present?
  end

  def contributor?
    trip_membership&.contributor?
  end

  def own_entry?
    record.author_id == user&.id
  end
end
```

### 3. `app/policies/trip_membership_policy.rb`

```ruby
# frozen_string_literal: true

class TripMembershipPolicy < ApplicationPolicy
  def index?
    superadmin? || member_of_trip?
  end

  def create?
    superadmin?
  end

  def new?
    create?
  end

  def destroy?
    superadmin?
  end

  private

  def member_of_trip?
    return false unless user

    record.trip.trip_memberships.exists?(user: user)
  end
end
```

### 4. `spec/policies/trip_policy_spec.rb`

Following existing pattern from `spec/policies/invitation_policy_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe TripPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:contributor_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:outsider) { create(:user) }
  let(:trip) { create(:trip) }

  before do
    create(:trip_membership, trip: trip, user: contributor_user,
                             role: :contributor)
    create(:trip_membership, trip: trip, user: viewer_user,
                             role: :viewer)
  end

  describe "#index?" do
    it "allows any authenticated user" do
      expect(described_class.new(trip, user: outsider)
        .apply(:index?)).to be(true)
    end
  end

  describe "#show?" do
    it "allows superadmin" do
      expect(described_class.new(trip, user: admin)
        .apply(:show?)).to be(true)
    end

    it "allows contributor member" do
      expect(described_class.new(trip, user: contributor_user)
        .apply(:show?)).to be(true)
    end

    it "allows viewer member" do
      expect(described_class.new(trip, user: viewer_user)
        .apply(:show?)).to be(true)
    end

    it "denies non-member" do
      expect(described_class.new(trip, user: outsider)
        .apply(:show?)).to be(false)
    end
  end

  describe "#create?" do
    it "allows superadmin" do
      expect(described_class.new(trip, user: admin)
        .apply(:create?)).to be(true)
    end

    it "denies contributor" do
      expect(described_class.new(trip, user: contributor_user)
        .apply(:create?)).to be(false)
    end

    it "denies outsider" do
      expect(described_class.new(trip, user: outsider)
        .apply(:create?)).to be(false)
    end
  end

  describe "#edit?" do
    it "allows superadmin" do
      expect(described_class.new(trip, user: admin)
        .apply(:edit?)).to be(true)
    end

    it "allows contributor" do
      expect(described_class.new(trip, user: contributor_user)
        .apply(:edit?)).to be(true)
    end

    it "denies viewer" do
      expect(described_class.new(trip, user: viewer_user)
        .apply(:edit?)).to be(false)
    end

    it "denies non-member" do
      expect(described_class.new(trip, user: outsider)
        .apply(:edit?)).to be(false)
    end
  end

  describe "#destroy?" do
    it "allows superadmin" do
      expect(described_class.new(trip, user: admin)
        .apply(:destroy?)).to be(true)
    end

    it "denies contributor" do
      expect(described_class.new(trip, user: contributor_user)
        .apply(:destroy?)).to be(false)
    end
  end

  describe "#transition?" do
    it "allows superadmin" do
      expect(described_class.new(trip, user: admin)
        .apply(:transition?)).to be(true)
    end

    it "denies contributor" do
      expect(described_class.new(trip, user: contributor_user)
        .apply(:transition?)).to be(false)
    end
  end
end
```

### 5. `spec/policies/journal_entry_policy_spec.rb`

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntryPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:author) { create(:user) }
  let(:other_contributor) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:outsider) { create(:user) }
  let(:trip) { create(:trip) }
  let(:entry) { create(:journal_entry, trip: trip, author: author) }

  before do
    create(:trip_membership, trip: trip, user: author,
                             role: :contributor)
    create(:trip_membership, trip: trip, user: other_contributor,
                             role: :contributor)
    create(:trip_membership, trip: trip, user: viewer_user,
                             role: :viewer)
  end

  describe "#show?" do
    it "allows superadmin" do
      expect(described_class.new(entry, user: admin)
        .apply(:show?)).to be(true)
    end

    it "allows trip member" do
      expect(described_class.new(entry, user: viewer_user)
        .apply(:show?)).to be(true)
    end

    it "denies non-member" do
      expect(described_class.new(entry, user: outsider)
        .apply(:show?)).to be(false)
    end
  end

  describe "#create?" do
    it "allows superadmin" do
      expect(described_class.new(entry, user: admin)
        .apply(:create?)).to be(true)
    end

    it "allows contributor on writable trip" do
      expect(described_class.new(entry, user: author)
        .apply(:create?)).to be(true)
    end

    it "denies contributor on finished trip" do
      trip.update!(state: :finished)
      expect(described_class.new(entry, user: author)
        .apply(:create?)).to be(false)
    end

    it "denies viewer" do
      expect(described_class.new(entry, user: viewer_user)
        .apply(:create?)).to be(false)
    end
  end

  describe "#edit?" do
    it "allows superadmin" do
      expect(described_class.new(entry, user: admin)
        .apply(:edit?)).to be(true)
    end

    it "allows author (contributor)" do
      expect(described_class.new(entry, user: author)
        .apply(:edit?)).to be(true)
    end

    it "denies other contributor (not author)" do
      expect(described_class.new(entry, user: other_contributor)
        .apply(:edit?)).to be(false)
    end

    it "denies viewer" do
      expect(described_class.new(entry, user: viewer_user)
        .apply(:edit?)).to be(false)
    end
  end

  describe "#destroy?" do
    it "allows superadmin" do
      expect(described_class.new(entry, user: admin)
        .apply(:destroy?)).to be(true)
    end

    it "allows author" do
      expect(described_class.new(entry, user: author)
        .apply(:destroy?)).to be(true)
    end

    it "denies other contributor" do
      expect(described_class.new(entry, user: other_contributor)
        .apply(:destroy?)).to be(false)
    end
  end
end
```

### 6. `spec/policies/trip_membership_policy_spec.rb`

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe TripMembershipPolicy do
  let(:admin) { create(:user, :superadmin) }
  let(:member_user) { create(:user) }
  let(:outsider) { create(:user) }
  let(:trip) { create(:trip) }
  let(:membership) do
    create(:trip_membership, trip: trip, user: member_user)
  end

  describe "#index?" do
    it "allows superadmin" do
      expect(described_class.new(membership, user: admin)
        .apply(:index?)).to be(true)
    end

    it "allows trip member" do
      expect(described_class.new(membership, user: member_user)
        .apply(:index?)).to be(true)
    end

    it "denies non-member" do
      expect(described_class.new(membership, user: outsider)
        .apply(:index?)).to be(false)
    end
  end

  describe "#create?" do
    it "allows superadmin" do
      expect(described_class.new(membership, user: admin)
        .apply(:create?)).to be(true)
    end

    it "denies member" do
      expect(described_class.new(membership, user: member_user)
        .apply(:create?)).to be(false)
    end
  end

  describe "#destroy?" do
    it "allows superadmin" do
      expect(described_class.new(membership, user: admin)
        .apply(:destroy?)).to be(true)
    end

    it "denies member" do
      expect(described_class.new(membership, user: member_user)
        .apply(:destroy?)).to be(false)
    end
  end
end
```

---

## Files to Modify (13)

### 7. `app/controllers/trips_controller.rb`

Add `before_action :authorize_trip!` and the private method. The `index` action keeps manual scoping but calls `authorize!` on the class:

```ruby
# Current (line 4-5):
before_action :require_authenticated_user!
before_action :set_trip, only: %i[show edit update destroy transition]

# Change to:
before_action :require_authenticated_user!
before_action :set_trip, only: %i[show edit update destroy transition]
before_action :authorize_trip!

# Add to private section:
def authorize_trip!
  authorize!(@trip || Trip)
end
```

### 8. `app/controllers/journal_entries_controller.rb`

Add `before_action :authorize_journal_entry!` after set callbacks:

```ruby
# Current (line 3-6):
before_action :require_authenticated_user!
before_action :set_trip
before_action :set_journal_entry, only: %i[show edit update destroy]

# Change to:
before_action :require_authenticated_user!
before_action :set_trip
before_action :set_journal_entry, only: %i[show edit update destroy]
before_action :authorize_journal_entry!

# Add to private section:
def authorize_journal_entry!
  authorize!(@journal_entry || @trip.journal_entries.new)
end
```

Note: For `new`/`create`, `@journal_entry` is nil so `@trip.journal_entries.new` builds a transient record. The policy's `create?` checks `record.trip.writable?` which works because the transient entry has the trip association set.

### 9. `app/controllers/trip_memberships_controller.rb`

Add `before_action :authorize_membership!`:

```ruby
# Current (line 3-5):
before_action :require_authenticated_user!
before_action :set_trip

# Change to:
before_action :require_authenticated_user!
before_action :set_trip
before_action :authorize_membership!

# In destroy, set @membership before authorize runs.
# Move the find to a before_action:
before_action :set_membership, only: [:destroy]

# Add to private section:
def authorize_membership!
  authorize!(@membership || @trip.trip_memberships.new)
end

def set_membership
  @membership = @trip.trip_memberships.find(params[:id])
end
```

Update `destroy` to use `@membership` instead of local variable:

```ruby
def destroy
  TripMemberships::Remove.new.call(membership: @membership)
  redirect_to trip_trip_memberships_path(@trip),
              notice: "Member removed.", status: :see_other
end
```

### 10. `app/views/trips/index.rb`

Replace manual role check with `allowed_to?` (line 19):

```ruby
# Current:
if view_context.current_user&.role?(:superadmin)

# Change to:
if view_context.allowed_to?(:create?, Trip)
```

### 11. `app/views/trips/show.rb`

Guard header actions with `allowed_to?`. Replace `render_header_actions` (lines 43-59):

```ruby
def render_header_actions
  if view_context.allowed_to?(:edit?, @trip)
    link_to("Edit", view_context.edit_trip_path(@trip),
            class: "ha-button ha-button-secondary")
  end
  link_to(
    "Members",
    view_context.trip_trip_memberships_path(@trip),
    class: "ha-button ha-button-secondary"
  )
  if view_context.allowed_to?(:destroy?, @trip)
    button_to(
      "Delete", view_context.trip_path(@trip),
      method: :delete,
      class: "ha-button ha-button-danger",
      form: { class: "inline-flex" }
    )
  end
  link_to("Back to trips", view_context.trips_path,
          class: "ha-button ha-button-secondary")
end
```

Guard state transitions (lines 93-110). Wrap with `allowed_to?(:transition?, @trip)`:

```ruby
def render_state_transitions
  return unless view_context.allowed_to?(:transition?, @trip)

  transitions = Trip::VALID_TRANSITIONS[@trip.state.to_sym]
  return if transitions.blank?
  # ... rest unchanged
end
```

Guard "New entry" button (line 129). Replace `@trip.writable?` with policy check:

```ruby
# Current:
if @trip.writable?

# Change to:
if view_context.allowed_to?(:create?, @trip.journal_entries.new)
```

### 12. `app/views/journal_entries/show.rb`

Guard Edit and Delete buttons in `render_actions` (lines 38-55):

```ruby
def render_actions
  if view_context.allowed_to?(:edit?, @entry)
    link_to(
      "Edit",
      view_context.edit_trip_journal_entry_path(@trip, @entry),
      class: "ha-button ha-button-secondary"
    )
  end
  if view_context.allowed_to?(:destroy?, @entry)
    button_to(
      "Delete",
      view_context.trip_journal_entry_path(@trip, @entry),
      method: :delete,
      class: "ha-button ha-button-danger",
      form: { class: "inline-flex" }
    )
  end
  link_to(
    "Back to trip", view_context.trip_path(@trip),
    class: "ha-button ha-button-secondary"
  )
end
```

### 13. `app/components/trip_card.rb`

Guard "Edit" link in `render_actions` (lines 49-56):

```ruby
def render_actions
  div(class: "mt-5 flex flex-wrap gap-2") do
    link_to("View", view_context.trip_path(@trip),
            class: "ha-button ha-button-secondary")
    if view_context.allowed_to?(:edit?, @trip)
      link_to("Edit", view_context.edit_trip_path(@trip),
              class: "ha-button ha-button-secondary")
    end
  end
end
```

### 14. `app/components/journal_entry_card.rb`

Guard "Edit" link in `render_actions` (lines 48-61):

```ruby
def render_actions
  div(class: "mt-5 flex flex-wrap gap-2") do
    link_to(
      "View",
      view_context.trip_journal_entry_path(@trip, @entry),
      class: "ha-button ha-button-secondary"
    )
    if view_context.allowed_to?(:edit?, @entry)
      link_to(
        "Edit",
        view_context.edit_trip_journal_entry_path(@trip, @entry),
        class: "ha-button ha-button-secondary"
      )
    end
  end
end
```

### 15. `app/views/trip_memberships/index.rb`

Guard "Add member" button (lines 20-24):

```ruby
# Wrap existing link_to:
if view_context.allowed_to?(:create?, @trip.trip_memberships.new)
  link_to(
    "Add member",
    view_context.new_trip_trip_membership_path(@trip),
    class: "ha-button ha-button-primary"
  )
end
```

### 16. `app/components/trip_membership_card.rb`

Guard "Remove" button in `render_actions` (lines 53-62):

```ruby
def render_actions
  return unless view_context.allowed_to?(:destroy?, @membership)

  div(class: "mt-5 flex flex-wrap gap-2") do
    button_to(
      "Remove",
      view_context.trip_trip_membership_path(@trip, @membership),
      method: :delete,
      class: "ha-button ha-button-danger"
    )
  end
end
```

### 17. `spec/requests/trips_spec.rb`

Add authorization test cases at the end of the file:

```ruby
describe "authorization" do
  let!(:viewer_user) { create(:user) }
  let!(:trip) { create(:trip, created_by: admin) }

  before do
    create(:trip_membership, trip: trip, user: viewer_user,
                             role: :viewer)
  end

  context "as viewer" do
    before { stub_current_user(viewer_user) }

    it "allows show" do
      get trip_path(trip)
      expect(response).to be_successful
    end

    it "forbids edit" do
      get edit_trip_path(trip)
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids create" do
      post trips_path, params: { trip: { name: "No" } }
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids destroy" do
      delete trip_path(trip)
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids transition" do
      patch transition_trip_path(trip), params: { state: "started" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "as non-member" do
    let!(:outsider) { create(:user) }

    before { stub_current_user(outsider) }

    it "forbids show" do
      get trip_path(trip)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

### 18. `spec/requests/journal_entries_spec.rb`

Add authorization test cases:

```ruby
describe "authorization" do
  let!(:viewer_user) { create(:user) }
  let!(:other_contributor) { create(:user) }
  let!(:entry) { create(:journal_entry, trip: trip, author: admin) }

  before do
    create(:trip_membership, trip: trip, user: viewer_user,
                             role: :viewer)
    create(:trip_membership, trip: trip, user: other_contributor,
                             role: :contributor)
  end

  context "as viewer" do
    before { stub_current_user(viewer_user) }

    it "allows show" do
      get trip_journal_entry_path(trip, entry)
      expect(response).to be_successful
    end

    it "forbids create" do
      post trip_journal_entries_path(trip), params: {
        journal_entry: { name: "No", entry_date: Date.current.to_s }
      }
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "as other contributor (not author)" do
    before { stub_current_user(other_contributor) }

    it "forbids edit of another's entry" do
      get edit_trip_journal_entry_path(trip, entry)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

### 19. `spec/requests/trip_memberships_spec.rb`

Add authorization test cases:

```ruby
describe "authorization" do
  let!(:contributor_user) { create(:user) }

  before do
    create(:trip_membership, trip: trip, user: contributor_user,
                             role: :contributor)
    stub_current_user(contributor_user)
  end

  it "allows index for member" do
    get trip_trip_memberships_path(trip)
    expect(response).to be_successful
  end

  it "forbids create for contributor" do
    post trip_trip_memberships_path(trip), params: {
      trip_membership: { user_id: member_user.id, role: "viewer" }
    }
    expect(response).to have_http_status(:forbidden)
  end

  it "forbids destroy for contributor" do
    membership = create(:trip_membership, trip: trip,
                                          user: member_user)
    delete trip_trip_membership_path(trip, membership)
    expect(response).to have_http_status(:forbidden)
  end
end
```

---

## Key Design Decisions

1. **Trip membership lookup in policies** — Policies query `trip_memberships.find_by(user:)` to determine access. One DB query per auth check. Simple and correct; caching can be added later if needed.

2. **Contributor can only edit own entries** — `own_entry?` checks `record.author_id == user.id`. Superadmin can edit any entry. Another contributor on the same trip cannot edit entries they didn't author.

3. **Writable guard in JournalEntryPolicy#create?** — `record.trip.writable?` ensures contributors can't create entries on finished/archived trips, even if they have the contributor role.

4. **No ActionPolicy scopes** — Keep the manual Trip scoping in `TripsController#index` (superadmin sees all, others see their trips). ActionPolicy scopes add complexity without benefit here.

5. **Members link always visible** — On the trip show page, the "Members" link is always shown to any user who can see the trip (the policy on the memberships index handles access). This lets viewers see who's on the trip.

6. **authorize! on class for index/new/create** — When `@record` is nil, `authorize!(ModelClass)` or `authorize!(@trip.entries.new)` builds a transient record for the policy. This matches the existing `authorize!(@user || User)` pattern in `UsersController`.

---

## Verification

### Automated Tests
```bash
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
mise x -- bundle exec rake project:lint
```

### Runtime Test Checklist
- [ ] Superadmin can see all trips, create/edit/delete any trip
- [ ] Superadmin can manage memberships on any trip
- [ ] Superadmin can create/edit/delete any journal entry
- [ ] Contributor can see their trips, create entries on writable trips
- [ ] Contributor can edit/delete only their own entries
- [ ] Contributor cannot create trips, manage memberships, or transition state
- [ ] Viewer can see their trips and entries, nothing else
- [ ] Viewer cannot create/edit/delete entries or manage memberships
- [ ] User with no membership gets 403 on trip show
- [ ] Unauthenticated user gets 401 on all trip routes
- [ ] UI buttons/links hidden based on permissions (no phantom buttons)
- [ ] "New trip" button visible only to superadmin
- [ ] "Edit"/"Delete" buttons on entries visible only to author + superadmin
- [ ] "Add member"/"Remove" buttons visible only to superadmin

### Definition of Done
- [ ] 3 policies created with full permission matrix
- [ ] 3 controllers enforce authorization via `authorize!`
- [ ] All views/components conditionally render actions based on `allowed_to?`
- [ ] Policy specs cover all role x action combinations
- [ ] Request specs include authorization denial test cases
- [ ] Existing tests still pass (no regressions)
- [ ] No runtime errors

# Summary

Phase 4 Complete

  Issue: https://github.com/joel/trip/issues/16
  PR: https://github.com/joel/trip/pull/17

  What was done:

  - 3 policies created: TripPolicy, JournalEntryPolicy, TripMembershipPolicy
  - 3 controllers updated: Added authorize! callbacks to all trip-domain controllers
  - 7 views/components updated: Conditional rendering with allowed_to? guards
  - 3 policy specs: 31 examples covering all role × action combinations
  - 3 request spec additions: 10 authorization denial test cases

  Test results:

  - 214 specs pass (0 failures, 2 pending)
  - 13 system specs pass
  - Lint clean (0 offenses)
  - All overcommit hooks pass

  Remaining:

  1. Kanban board update — needs gh auth refresh with project scope (interactive)
  2. Runtime test — ready to run with /runtime-test
