# Security Review -- feature/phase-15-feed-wall

**Date:** 2026-04-12
**Reviewer:** Claude Opus 4.6 (adversarial pass)
**Scope:** `git diff main...HEAD` (14 commits, 27 files changed)

---

## Critical (must fix before merge)

### C-1: Stale polymorphic redirect in ReactionsController#destroy

**File:** `app/controllers/reactions_controller.rb:43`

```ruby
format.html do
  redirect_to [@trip, @journal_entry], status: :see_other
end
```

The `show` route for journal entries was removed (`except: %i[index show]` in routes.rb), but the HTML fallback in `ReactionsController#destroy` still uses `redirect_to [@trip, @journal_entry]`, which resolves to the now-deleted `trip_journal_entry_path`. This will raise a `NoMethodError` (or `ActionController::UrlGenerationError`) at runtime for any non-Turbo request to delete a reaction.

**Impact:** Runtime crash for users with JS disabled or degraded Turbo connections.

**Fix:** Replace with `redirect_to trip_path(@trip, anchor: dom_id(@journal_entry)), status: :see_other` -- consistent with all other controllers in this diff.

---

## Warning (should fix or consciously accept)

### W-1: `raw(safe(...))` on Action Text body -- relocated but unchanged pattern

**File:** `app/components/journal_entry_card.rb:156`

```ruby
div(class: "prose prose-lg dark:prose-invert max-w-none mb-6") { raw(safe(@entry.body.to_s)) }
```

This was previously in the deleted `app/views/journal_entries/show.rb:114` and has been moved to the card component. The pattern itself is acceptable for Action Text (`has_rich_text :body`), which sanitizes HTML on input via the Rails built-in sanitizer. However, this card is now rendered for **every entry on the trip page** (versus previously only on a dedicated show page), which increases the attack surface area:

- If an attacker bypasses Action Text sanitization (e.g., via a future Rails CVE), the XSS payload now executes on the trip show page alongside all other entries and subscription toggle forms, enabling CSRF-style attacks against the feed.
- The body is rendered server-side and only hidden by the `hidden` attribute, so any malicious HTML is present in the DOM even before the user expands the card.

**Recommendation:** Consider rendering the body lazily via Turbo Frame (loaded on expand) rather than server-side hidden content. Alternatively, add an explicit `ActionText::Content` sanitization pass on output as defense-in-depth. This is low-probability but higher impact in the new feed context.

### W-2: Auto-subscribe creates subscriptions for all trip members without consent

**File:** `app/actions/journal_entries/create.rb:23-30`

```ruby
def subscribe_trip_members(entry)
  user_ids = entry.trip.members.pluck(:id) |
             [entry.author_id]
  user_ids.each do |uid|
    entry.journal_entry_subscriptions
         .find_or_create_by!(user_id: uid)
  end
  Success()
end
```

Previously, only the author was auto-subscribed. Now **all trip members** are auto-subscribed to every new journal entry. While users can mute via the toggle, this is an opt-out model. Security/privacy concerns:

- A user who is a member of a large shared trip will receive notification emails for every new entry without having opted in.
- The `find_or_create_by!` with `user_id` could fail if a user is deleted between the `pluck` and the `find_or_create_by!` (FK violation), though this is a race condition rather than a security issue.

**Recommendation:** This is a product decision, but document it and ensure the mute toggle is prominently visible. No code fix needed if the behavior is intentional.

### W-3: Missing eager loads cause N+1 queries on feed page

**File:** `app/controllers/trips_controller.rb:20-26` and `app/components/journal_entry_card.rb:187,207,303`

The trip show action loads:
```ruby
.includes(:author, :journal_entry_subscriptions, images_attachments: :blob)
```

But the card component accesses `@entry.comments.chronological`, `@entry.comments.count`, and `@entry.reactions.group(:emoji).count` -- none of which are eager-loaded. Since the expandable body is rendered server-side (just `hidden`), these queries fire on every page load for every entry. With 20 entries, this generates 40+ additional queries.

**Impact:** Performance degradation, not a direct security vulnerability. However, on a high-traffic page, this could enable a denial-of-service amplification if an attacker creates many entries on a shared trip.

**Recommendation:** Add `:comments` and `:reactions` to the `includes` chain in `TripsController#show`, or defer the expandable body to a lazy Turbo Frame.

---

## Informational (no action required)

### I-1: Authentication and authorization coverage is complete

All new and modified controllers maintain the `before_action :require_authenticated_user!` guard. Authorization checks are present:

| Controller | Auth Check |
|---|---|
| `JournalEntriesController` | `authorize_journal_entry!` via `authorize!(@journal_entry \|\| @trip.journal_entries.new)` |
| `JournalEntrySubscriptionsController` | `authorize_entry!` via `authorize!(@journal_entry, with: JournalEntryPolicy, to: :show?)` |
| `CommentsController` | `authorize_comment!` via `authorize!(@comment \|\| @journal_entry.comments.new(user: current_user))` |
| `ReactionsController` | `authorize_reaction!` / `set_and_authorize_reaction!` |
| `TripsController` | `authorize_trip!` via `authorize!(@trip \|\| Trip)` |

No authorization bypasses were found. The subscription controller correctly checks `show?` policy (membership required) before allowing subscribe/unsubscribe.

### I-2: Strong parameters are properly enforced

`JournalEntriesController#journal_entry_params` uses `params.expect(journal_entry: [...])` with an explicit allowlist. No mass assignment risk.

### I-3: CSRF protection on subscription toggle

The `JournalEntryFollowButton` component uses `button_to` which generates a mini-form with Rails' CSRF token. The `JournalEntrySubscriptionsController` inherits from `ApplicationController` which includes default CSRF protection. Both `create` (POST) and `destroy` (DELETE) paths are protected. Turbo Stream responses include the CSRF token in the replacement HTML.

### I-4: DOM ID predictability is acceptable

DOM IDs like `comments_<uuid>`, `reaction_summary_<uuid>`, and `journal_entry_<uuid>_mute` use UUIDs. While technically predictable by anyone who knows the entry ID, Turbo Stream replacements require a valid authenticated session with appropriate authorization (policy check), so DOM ID knowledge alone is insufficient for attacks.

### I-5: Stimulus controller is safe from DOM XSS

`app/javascript/controllers/feed_entry_controller.js` uses:
- `textContent` (not `innerHTML`) for label updates
- `hidden` attribute toggle (boolean)
- Hardcoded `rotate(180deg)` for chevron transform

No user-controlled input flows into DOM mutation methods.

### I-6: Notification card links correctly retargeted

`app/components/notification_card.rb` now links to `trip_path(..., anchor: "journal_entry_<id>")` instead of the removed `trip_journal_entry_path`. The anchor uses the entry UUID, which is already known to the notification recipient (they received the notification because they are subscribed).

### I-7: Mailer URL changes are safe

`app/mailers/notification_mailer.rb` switched from `trip_journal_entry_url` to `trip_url(@trip, anchor: "journal_entry_#{@entry.id}")`. The anchor contains the UUID (already known to the email recipient) and does not leak additional information.

### I-8: Nested resource scoping is correct

The `set_journal_entry` method in both `JournalEntrySubscriptionsController` and `JournalEntriesController` uses `@trip.journal_entries.find(params[:id])`, which scopes the lookup to the parent trip. This prevents cross-trip entry access even without authorization.

### I-9: No new dependencies

No changes to `Gemfile` or `Gemfile.lock` in this diff.

### I-10: No secrets or credentials in the diff

The diff contains no tokens, API keys, or sensitive configuration.

---

## Not applicable

| Category | Reason |
|---|---|
| Invitation/token flows | No token-based flows introduced or modified |
| File upload validation | No changes to upload handling; existing `has_many_attached :images` unchanged |
| Raw SQL | No raw SQL fragments in the diff |
| Secrets & configuration | No env vars or credentials touched |
| Dependencies | No new gems or packages |

---

## Summary

| Severity | Count | Action |
|---|---|---|
| Critical | 1 | C-1: Fix stale redirect in ReactionsController#destroy |
| Warning | 3 | W-1: Accept (defense-in-depth); W-2: Accept (product decision); W-3: Fix or defer |
| Informational | 10 | No action required |

The branch has one clear bug (C-1) where a route removal was incompletely propagated. The `raw(safe(...))` pattern for Action Text is pre-existing and acceptable, though the increased exposure in the feed context warrants awareness. Authorization, CSRF, and input validation are all properly maintained.
