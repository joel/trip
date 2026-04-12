# UX Review -- feature/phase-15-feed-wall

## Scope

This review covers the conversion of journal entries from dedicated show pages to an inline feed wall on the trip show page. Key surfaces reviewed:

- `app/views/trips/show.rb` -- trip show page with embedded journal feed
- `app/components/journal_entry_card.rb` -- expandable feed card
- `app/components/journal_entry_footer.rb` -- collapsed card footer (stats + toggle)
- `app/components/journal_entry_follow_button.rb` -- mute/unmute bell toggle
- `app/components/journal_entry_empty_state.rb` -- empty feed CTA
- `app/components/reaction_summary.rb` -- emoji reaction buttons
- `app/javascript/controllers/feed_entry_controller.js` -- Stimulus expand/collapse
- `app/controllers/trips_controller.rb` -- eager loading
- `app/controllers/reactions_controller.rb` -- HTML fallback redirect
- `app/controllers/journal_entries_controller.rb` -- post-action redirects
- `config/routes.rb` -- show route removal

---

## Broken (blocks usability)

### 1. Stale HTML fallback redirect in `reactions#destroy`

**File:** `app/controllers/reactions_controller.rb`, line 43

```ruby
format.html do
  redirect_to [@trip, @journal_entry], status: :see_other
end
```

`redirect_to [@trip, @journal_entry]` generates a GET to `/trips/:id/journal_entries/:id`, which no longer has a `show` route (removed by `except: %i[index show]`). If Turbo fails and the browser falls back to HTML, this produces a routing error.

**Fix:** Change to `redirect_to trip_path(@trip, anchor: dom_id(@journal_entry)), status: :see_other` -- consistent with every other controller in this branch.

---

### 2. No `aria-expanded` on the expand/collapse toggle

**File:** `app/components/journal_entry_footer.rb`, lines 59-74  
**File:** `app/javascript/controllers/feed_entry_controller.js`

The "Read more" / "Collapse" button has no `aria-expanded` attribute. Screen readers cannot determine whether the expandable region is open or closed. The expandable body (`data-feed-entry-target="body"`) also has no `aria-controls` or `id` linking it to the toggle.

**Fix:**
- Add `aria_expanded: "false"` to the toggle button in `render_toggle`.
- Add an `id` (e.g., `"entry_body_#{@entry.id}"`) to the expandable body div.
- Add `aria_controls: "entry_body_#{@entry.id}"` to the toggle button.
- Update `feed_entry_controller.js` to toggle `aria-expanded` on each click.

---

## Friction (degrades experience)

### 3. Mute toggle button has no visible text label

**File:** `app/components/journal_entry_follow_button.rb`

The bell icon buttons have `title` attributes ("Notifications on -- click to mute" / "Notifications off -- click to resume"), which appear as tooltips on hover. However:
- No `aria-label` is set -- screen readers will announce only the form's action URL.
- The icons use `aria_hidden: "true"`, making the button effectively empty for assistive technology.

**Fix:** Add `aria_label:` matching the `title` text to each `button_to` call, or add a `<span class="sr-only">` with the label text inside the button block.

### 4. Progressive enhancement: expand/collapse requires JavaScript

**Files:** `journal_entry_footer.rb`, `journal_entry_card.rb`, `feed_entry_controller.js`

The expandable body is rendered with `hidden: true` and toggled by Stimulus. Without JavaScript:
- The "Read more" button does nothing (it is a plain `<button>` with a Stimulus action).
- The full body content (rich text, images, reactions, comments, delete action) is permanently hidden.
- Users cannot access comments, reactions, or the delete button.

**Recommended approach:**
- Consider using a `<details>/<summary>` pattern for native expand/collapse that works without JS, then enhance with Stimulus for animation/smooth transitions.
- Alternatively, render the body visible by default (no `hidden: true`) and let the Stimulus controller add `hidden` on connect, so no-JS users see all content.

### 5. Comment count in footer triggers per-entry SQL query

**File:** `app/components/journal_entry_footer.rb`, line 50

```ruby
count = @entry.comments.count
```

This executes a `SELECT COUNT(*)` for every entry in the feed. Similarly, `@entry.reactions.group(:emoji).count` on line 31 runs an aggregate query per entry. With 20 entries, this is 40 extra SQL queries.

**Note:** These are not caught by Bullet (aggregate queries), but they are avoidable. Consider:
- Adding `counter_cache: true` on the `comments` and `reactions` associations.
- Or including `:comments` and `:reactions` in the eager load and using `.size` instead of `.count`.

### 6. `ReactionSummary#user_reacted?` uses `exists?` per emoji

**File:** `app/components/reaction_summary.rb`, line 79

```ruby
@entry.reactions.exists?(user: current, emoji: emoji)
```

Called once per emoji (6 emojis), this generates 6 SQL queries per entry when expanded. With reactions eager-loaded, this could use Ruby-level filtering instead:

```ruby
@entry.reactions.any? { |r| r.user_id == current.id && r.emoji == emoji }
```

### 7. Full description rendered twice when expanded

**File:** `app/components/journal_entry_card.rb`

When the card is expanded, the 2-line clamped description (`render_description`, line 126) is hidden via the Stimulus controller, and the full description (`render_full_description`, line 151) is shown. However, both are always rendered in the HTML. The clamped description uses `line-clamp-2` and the Stimulus controller hides/shows the preview target. This is fine functionally, but if the description is very long, it doubles the payload. Minor issue.

---

## Suggestions (nice to have)

### 8. Anchor scroll after create/update could auto-expand the card

When creating or updating an entry, the controller redirects to `trip_path(@trip, anchor: dom_id(entry))`. The browser scrolls to the card, but it remains collapsed. The user has to click "Read more" to verify their content. Consider adding a URL parameter (e.g., `?expanded=journal_entry_123`) and having the Stimulus controller auto-expand on connect if it matches.

### 9. Newest-first ordering is good for active trips

The `reverse_chronological` scope (`entry_date DESC, created_at DESC`) puts the newest entries at the top, which makes sense for an active trip feed. For archived/finished trips, chronological order might tell a better story, but this is a future consideration, not a current issue.

### 10. Feed header "The story so far" is a nice touch

The overline "JOURNAL FEED" + heading "The story so far" provides good context. The "New Entry" button with the Plus icon is clearly the primary action, using `ha-button-primary`.

### 11. Empty state is well-implemented

`JournalEntryEmptyState` has a clear heading ("No entries yet"), descriptive text, and a CTA that is authorization-gated (`can_create?`). Viewers who cannot create entries see the empty state without a confusing button.

### 12. Consider keyboard focus management on expand

When "Read more" is clicked, focus stays on the toggle button. The expanded content (comments, reactions) is below the fold. Consider moving focus to the first element of the expanded body after toggle, especially for keyboard users.

---

## N+1 / Eager Loading Analysis

### Current eager loading in `trips_controller#show`:

```ruby
@trip.journal_entries
     .reverse_chronological
     .includes(:author, :journal_entry_subscriptions, images_attachments: :blob)
```

### What is covered:
- `:author` -- used in `render_meta_line` (initials, name) -- OK
- `:journal_entry_subscriptions` -- used in `render_mute_toggle` (`.any?` check) -- OK
- `images_attachments: :blob` -- used in `render_cover_image` and `render_images` -- OK

### What is NOT covered (potential N+1):

| Association | Where Used | Impact |
|---|---|---|
| `:comments` | `JournalEntryFooter#render_comment_count` (`.count`) | 1 query per entry, collapsed state |
| `:reactions` | `JournalEntryFooter#render_reaction_pills` (`.group(:emoji).count`) | 1 query per entry, collapsed state |
| `comments: :user` | `CommentCard#render_header` (`.user.name`) | N queries when expanded |
| `:reactions` (exists?) | `ReactionSummary#user_reacted?` | Up to 6 queries per entry when expanded |

### Recommendation:

Add `:comments` and `:reactions` to the includes. The footer queries run on every card load (collapsed), so they contribute to page load time proportional to the number of entries:

```ruby
.includes(
  :author,
  :journal_entry_subscriptions,
  :reactions,
  comments: :user,
  images_attachments: :blob
)
```

Then change `JournalEntryFooter` to use `.size` (uses cached count from eager load) instead of `.count` (always fires SQL).

---

## Authorization-Aware UI

- **Edit link**: Gated by `allowed_to?(:edit?, @entry)` -- correct
- **Delete button**: Gated by `allowed_to?(:destroy?, @entry)`, only visible when expanded -- correct
- **New Entry button**: Gated by `allowed_to?(:create?, @trip.journal_entries.new)` -- correct
- **Comment form**: Gated by `allowed_to?(:create?, new_comment)` -- correct
- **Mute toggle**: Only shown when `current_user` exists -- correct
- **Empty state CTA**: Gated by `can_create?` -- correct

No phantom buttons detected.

---

## Routes Verification

Routes correctly exclude `index` and `show`:

```ruby
resources :journal_entries, except: %i[index show]
```

Remaining CRUD routes (new, create, edit, update, destroy) plus nested subscription, comments, and reactions are intact.

---

## Screenshots reviewed

Code-only review (no `agent-browser` available in this session). The following surfaces should be visually verified:

- Trip show page with 0 entries (empty state)
- Trip show page with multiple entries (collapsed feed)
- Expanded card with comments and reactions
- Mute toggle in both states (subscribed/muted)
- Mobile viewport (375px) for card layout
- Dark mode for all above states
