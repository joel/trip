# Phase 5: Comments, Reactions, and Checklists

## Context

Phases 1-4 are complete. The PRP's Phase 5 (Rich Text & Media) was already delivered in Phase 3 — Trix editor, Action Text, Active Storage, and image uploads are fully working. This plan implements the PRP's **Phase 6** content as our **Phase 5**, adding the social and organizational layer to trips: comments on journal entries, emoji reactions on trips/entries/comments, and trip checklists with sections and items.

**Issue:** To be created on GitHub (joel/trip)

---

## Scope

### New Models (5)
- `Comment` — belongs_to journal_entry + user, plain text body
- `Reaction` — polymorphic (Trip, JournalEntry, Comment), emoji string, unique per user+emoji+reactable
- `Checklist` — belongs_to trip, name, position
- `ChecklistSection` — belongs_to checklist, name, position
- `ChecklistItem` — belongs_to checklist_section, content, completed boolean, position

### Permission Matrix

| Resource | Action | Superadmin | Contributor | Viewer | No Membership |
|----------|--------|-----------|-------------|--------|---------------|
| Comment | show | yes | yes (member) | yes (member) | no |
| Comment | create | yes | yes (member) | yes (member) | no |
| Comment | update/destroy | yes | own only | own only | no |
| Reaction | create/destroy | yes | yes (member) | yes (member) | no |
| Checklist | index/show | yes | yes (member) | yes (member) | no |
| Checklist | create/update/destroy | yes | yes (member) | no | no |
| ChecklistItem | toggle | yes | yes (member) | no | no |

### State-Based Behavior

| State | Comments/Reactions | Checklists |
|-------|-------------------|------------|
| planning | Full | Full CRUD |
| started | Full | Full CRUD |
| finished | **Full** (still allowed) | Read-only |
| cancelled | Read-only | Read-only |
| archived | Read-only | Read-only |

Key: Comments/reactions remain open on finished trips (users can discuss after the trip ends). Checklists lock with journal entries.

---

## Files to Create

### Migrations (5)

1. `db/migrate/TIMESTAMP_create_comments.rb`

```ruby
class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments, id: :uuid do |t|
      t.references :journal_entry, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end

    add_index :comments, [:journal_entry_id, :created_at]
  end
end
```

2. `db/migrate/TIMESTAMP_create_reactions.rb`

```ruby
class CreateReactions < ActiveRecord::Migration[8.0]
  def change
    create_table :reactions, id: :uuid do |t|
      t.string :reactable_type, null: false
      t.uuid :reactable_id, null: false
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :emoji, null: false
      t.datetime :created_at, null: false
    end

    add_index :reactions, [:reactable_type, :reactable_id]
    add_index :reactions, [:reactable_type, :reactable_id, :user_id, :emoji],
              unique: true, name: "idx_reactions_uniqueness"
  end
end
```

3. `db/migrate/TIMESTAMP_create_checklists.rb`

```ruby
class CreateChecklists < ActiveRecord::Migration[8.0]
  def change
    create_table :checklists, id: :uuid do |t|
      t.references :trip, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
```

4. `db/migrate/TIMESTAMP_create_checklist_sections.rb`

```ruby
class CreateChecklistSections < ActiveRecord::Migration[8.0]
  def change
    create_table :checklist_sections, id: :uuid do |t|
      t.references :checklist, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
```

5. `db/migrate/TIMESTAMP_create_checklist_items.rb`

```ruby
class CreateChecklistItems < ActiveRecord::Migration[8.0]
  def change
    create_table :checklist_items, id: :uuid do |t|
      t.references :checklist_section, type: :uuid, null: false, foreign_key: true
      t.string :content, null: false
      t.boolean :completed, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
```

### Models (5)

6. `app/models/comment.rb`

```ruby
# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :user

  validates :body, presence: true

  scope :chronological, -> { order(created_at: :asc, id: :asc) }
end
```

7. `app/models/reaction.rb`

```ruby
# frozen_string_literal: true

class Reaction < ApplicationRecord
  belongs_to :reactable, polymorphic: true
  belongs_to :user

  validates :emoji, presence: true
  validates :emoji, uniqueness: {
    scope: [:reactable_type, :reactable_id, :user_id]
  }
end
```

8. `app/models/checklist.rb`

```ruby
# frozen_string_literal: true

class Checklist < ApplicationRecord
  belongs_to :trip

  has_many :checklist_sections, -> { order(position: :asc) },
           dependent: :destroy

  validates :name, presence: true

  scope :ordered, -> { order(position: :asc, created_at: :asc) }
end
```

9. `app/models/checklist_section.rb`

```ruby
# frozen_string_literal: true

class ChecklistSection < ApplicationRecord
  belongs_to :checklist

  has_many :checklist_items, -> { order(position: :asc) },
           dependent: :destroy

  validates :name, presence: true
end
```

10. `app/models/checklist_item.rb`

```ruby
# frozen_string_literal: true

class ChecklistItem < ApplicationRecord
  belongs_to :checklist_section

  validates :content, presence: true

  scope :ordered, -> { order(position: :asc, created_at: :asc) }

  def toggle!
    update!(completed: !completed)
  end
end
```

### Actions (9)

11. `app/actions/comments/create.rb` — persist + emit "comment.created"
12. `app/actions/comments/update.rb` — update + emit "comment.updated"
13. `app/actions/comments/delete.rb` — destroy + emit "comment.deleted"
14. `app/actions/reactions/toggle.rb` — find existing and destroy, or create new. Emit "reaction.created" or "reaction.removed"
15. `app/actions/checklists/create.rb` — persist + emit "checklist.created"
16. `app/actions/checklists/update.rb` — update + emit "checklist.updated"
17. `app/actions/checklists/delete.rb` — destroy + emit "checklist.deleted"
18. `app/actions/checklist_items/toggle.rb` — toggle completed boolean + emit "checklist_item.toggled"
19. `app/actions/checklist_items/create.rb` — persist + emit "checklist_item.created"

Follow existing pattern from `app/actions/journal_entries/create.rb`: inherit from `BaseAction`, use `yield` for monadic flow, catch `ActiveRecord::RecordInvalid`, emit events via `Rails.event.notify`.

### Policies (4)

20. `app/policies/comment_policy.rb`

```ruby
# frozen_string_literal: true

class CommentPolicy < ApplicationPolicy
  def show?
    superadmin? || member?
  end

  def create?
    superadmin? || (member? && commentable?)
  end

  def update?
    superadmin? || (own_comment? && commentable?)
  end

  def destroy?
    superadmin? || (own_comment? && commentable?)
  end

  private

  def trip
    record.is_a?(Comment) ? record.journal_entry.trip : record.trip
  end

  def trip_membership
    return unless user

    trip.trip_memberships.find_by(user: user)
  end

  def member?
    trip_membership.present?
  end

  def own_comment?
    member? && record.user_id == user&.id
  end

  def commentable?
    trip.commentable?
  end
end
```

21. `app/policies/reaction_policy.rb` — same structure as CommentPolicy, create/destroy only (no update)

22. `app/policies/checklist_policy.rb`

```ruby
# frozen_string_literal: true

class ChecklistPolicy < ApplicationPolicy
  def index?
    superadmin? || member?
  end

  def show?
    superadmin? || member?
  end

  def create?
    superadmin? || (contributor? && trip.writable?)
  end

  def new?
    create?
  end

  def edit?
    superadmin? || (contributor? && trip.writable?)
  end

  def update?
    edit?
  end

  def destroy?
    superadmin? || (contributor? && trip.writable?)
  end

  private

  def trip
    record.is_a?(Checklist) ? record.trip : record.trip
  end

  def trip_membership
    return unless user

    trip.trip_memberships.find_by(user: user)
  end

  def member?
    trip_membership.present?
  end

  def contributor?
    trip_membership&.contributor?
  end
end
```

23. `app/policies/checklist_item_policy.rb` — toggle: contributor or superadmin + writable? guard

### Controllers (4)

24. `app/controllers/comments_controller.rb` — nested under trips/journal_entries; actions: create, update, destroy
25. `app/controllers/reactions_controller.rb` — nested under trips/journal_entries; actions: create, destroy
26. `app/controllers/checklists_controller.rb` — nested under trips; actions: index, new, create, show, edit, update, destroy
27. `app/controllers/checklist_items_controller.rb` — nested under trips/checklists; actions: create, toggle, destroy

Follow existing pattern: `before_action` chain (require_authenticated_user → set parent → set record → authorize), use action classes, pattern match on Success/Failure.

### Views/Components (12)

28. `app/components/comment_card.rb` — renders comment with author, timestamp, edit/delete guards
29. `app/components/comment_form.rb` — inline form for new/edit comment (text area + submit)
30. `app/components/reaction_summary.rb` — renders grouped emoji counts with toggle buttons
31. `app/components/checklist_card.rb` — renders checklist with sections and items
32. `app/components/checklist_form.rb` — form for new/edit checklist
33. `app/components/checklist_item_row.rb` — single item with checkbox toggle
34. `app/views/checklists/index.rb` — list of checklists for a trip
35. `app/views/checklists/show.rb` — single checklist with sections/items
36. `app/views/checklists/new.rb` — new checklist form
37. `app/views/checklists/edit.rb` — edit checklist form

### Modify existing views (3)

38. `app/views/journal_entries/show.rb` — add comments section + reaction summary below entry body
39. `app/views/trips/show.rb` — add "Checklists" link in header actions
40. `app/components/journal_entry_card.rb` — show comment count badge

### Subscribers (3)

41. `app/subscribers/comment_subscriber.rb` — emit handler for comment events (logging for now)
42. `app/subscribers/reaction_subscriber.rb` — emit handler for reaction events
43. `app/subscribers/checklist_subscriber.rb` — emit handler for checklist events

### Update event_subscribers.rb initializer

44. Register new subscribers in `config/initializers/event_subscribers.rb`

### Routes

45. Update `config/routes.rb` — add nested routes

### Model associations (modify existing)

46. `app/models/journal_entry.rb` — add `has_many :comments, dependent: :destroy` and `has_many :reactions, as: :reactable, dependent: :destroy`
47. `app/models/trip.rb` — add `has_many :checklists, dependent: :destroy` and `has_many :reactions, as: :reactable, dependent: :destroy` and `def commentable?` helper
48. `app/models/user.rb` — add `has_many :comments, dependent: :destroy` and `has_many :reactions, dependent: :destroy`

---

## Specs to Create

### Factories (5)
49. `spec/factories/comments.rb`
50. `spec/factories/reactions.rb`
51. `spec/factories/checklists.rb`
52. `spec/factories/checklist_sections.rb`
53. `spec/factories/checklist_items.rb`

### Model Specs (5)
54. `spec/models/comment_spec.rb` — validations, associations, chronological scope
55. `spec/models/reaction_spec.rb` — validations, uniqueness, polymorphic associations
56. `spec/models/checklist_spec.rb` — validations, associations, position ordering
57. `spec/models/checklist_section_spec.rb` — validations, associations
58. `spec/models/checklist_item_spec.rb` — validations, toggle behavior

### Action Specs (5)
59. `spec/actions/comments/create_spec.rb`
60. `spec/actions/reactions/toggle_spec.rb`
61. `spec/actions/checklists/create_spec.rb`
62. `spec/actions/checklist_items/toggle_spec.rb`
63. `spec/actions/checklist_items/create_spec.rb`

### Policy Specs (4)
64. `spec/policies/comment_policy_spec.rb` — all role x action x state combinations
65. `spec/policies/reaction_policy_spec.rb`
66. `spec/policies/checklist_policy_spec.rb`
67. `spec/policies/checklist_item_policy_spec.rb`

### Request Specs (4)
68. `spec/requests/comments_spec.rb` — CRUD + authorization denial
69. `spec/requests/reactions_spec.rb` — toggle + authorization denial
70. `spec/requests/checklists_spec.rb` — CRUD + authorization denial
71. `spec/requests/checklist_items_spec.rb` — toggle + authorization denial

---

## Key Design Decisions

1. **Comments are inline on entry show page** — No separate comment index/show pages. Comments render below the entry body with an inline form. This keeps the UX simple — users don't navigate away to comment.

2. **Reactions use a toggle action** — `Reactions::Toggle` finds an existing reaction and destroys it, or creates one if not found. This is idempotent and simplifies the client interaction (one endpoint, one button click).

3. **Reaction is polymorphic** — Works on Trip, JournalEntry, and Comment. The `reactable_type` + `reactable_id` pattern. Controller is nested under journal_entries for now (reactions on trips/comments can be added later via the same model).

4. **Checklists are trip-level, not entry-level** — Per the PRP, checklists belong to trips (packing lists, todo lists), not individual journal entries. They have their own CRUD pages under `/trips/:id/checklists`.

5. **Checklist hierarchy: Checklist -> Section -> Item** — Three levels per PRP. Sections group items within a checklist (e.g., "Clothing", "Documents" within a "Packing List").

6. **Comments/reactions allowed on finished trips** — Per PRP state behavior table. Users can discuss entries after a trip ends. Only cancelled/archived blocks everything.

7. **Trip#commentable? helper** — New method: `planning? || started? || finished?`. Separate from `writable?` (which is `planning? || started?`). Used by CommentPolicy and ReactionPolicy.

8. **No Turbo Streams in this phase** — The PRP mentions Turbo Streams for real-time checklist updates, but for this phase we'll use standard form submissions with redirects. Turbo Stream enhancement can be a follow-up.

---

## Routes Structure

```ruby
resources :trips do
  resources :journal_entries, except: [:index] do
    resources :comments, only: %i[create update destroy]
    resources :reactions, only: %i[create destroy]
  end
  resources :checklists do
    resources :checklist_items, only: %i[create destroy] do
      member do
        patch :toggle
      end
    end
  end
  resources :trip_memberships, only: %i[index new create destroy], path: "members"
  member do
    patch :transition
  end
end
```

---

## Verification

### Automated Tests
```bash
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
mise x -- bundle exec rake project:lint
```

### Runtime Test Checklist
- [ ] Superadmin can comment on any journal entry
- [ ] Contributor can comment on entries in their trip
- [ ] Viewer can comment on entries in their trip
- [ ] Users can only edit/delete their own comments
- [ ] Reactions toggle on/off with single click
- [ ] Reaction counts display correctly
- [ ] Superadmin can create checklists on any trip
- [ ] Contributor can create checklists on their trip
- [ ] Viewer cannot create checklists
- [ ] Checklist items toggle completed state
- [ ] Comments/reactions work on finished trips
- [ ] Comments/reactions blocked on cancelled/archived trips
- [ ] Checklists blocked on finished/cancelled/archived trips
- [ ] No phantom UI buttons for unauthorized users

### Definition of Done
- [ ] 5 models created with validations and associations
- [ ] 9 actions with event emission
- [ ] 4 policies with full permission matrix
- [ ] 4 controllers with authorize! enforcement
- [ ] 12 views/components with allowed_to? guards
- [ ] 3 subscribers registered
- [ ] All existing tests still pass (no regressions)
- [ ] Runtime verification via agent-browser
