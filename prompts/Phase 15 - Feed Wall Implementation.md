# Phase 15 — Journal Entries Feed Wall (Implementation Plan)

## Context

The Journal Entries feature today behaves like a blog: each entry has its own
dedicated page (`GET /trips/:trip_id/journal_entries/:id`) and the trip show
page only renders summary cards with a "Read more →" link that navigates away.
This fragments the story of a trip and forces the user into context switches
that are not aligned with how a journal timeline should read.

This phase reframes journal entries as a **feed wall**: the trip show page
becomes the single surface for every entry, each card expands in-place for the
full content, reactions and comments are inline, and subscribing to an entry
is the default (with a quick mute toggle on every card).

### Goals

1. **Single-page feed.** Every entry for a trip is rendered directly under the
   trip description, newest first, no navigation required.
2. **Inline expand.** "Read more" expands the card in place (body, images,
   reactions, comments) — no route change.
3. **Follow by default.** When an entry is created, every trip member is
   auto-subscribed. Users can mute from the feed.
4. **Quick mute toggle on every card.** A small bell icon (Following / Muted)
   lives on every entry in the feed.
5. **Kill the show page.** `journal_entries#show` and its view are removed.
6. **Reverse order.** Newest entries at the top.

### Non-goals (explicit)

- Do **not** redesign comment or reaction UI — they already work via Turbo
  Streams; we just relocate them inside the expanded card.
- Do **not** touch MCP tools — they all go through the action layer
  (`JournalEntries::Create/Update/Delete`, `Comments::Create`, `Reactions::Toggle`),
  not HTTP routes. See `app/mcp/tools/` — no tool builds a URL to the show page.
- Do **not** change the notifications domain (Phase 11). This phase only
  changes who is subscribed by default. The delivery mechanism is unchanged.
- Do **not** add pagination. Current volume is low; we load all entries on
  trip show as today. Flag for a follow-up phase if perf becomes an issue.

### Load-bearing facts from the codebase

- `app/actions/journal_entries/create.rb:23-28` — author is auto-subscribed
  via `find_or_create_by!` in the Create action. This is **the only place**
  a subscription is created automatically today. Inverting follow default
  happens here, not in a model callback.
- `app/models/journal_entry.rb:18-20` — `.chronological` scope orders oldest
  first. Feed needs newest first.
- `app/controllers/trips_controller.rb:19-24` — trip show loads
  `@trip.journal_entries.chronological.includes(:comments)`. This is the
  only caller that feeds the wall.
- `config/routes.rb:29` — `resources :journal_entries, except: [:index]` with
  nested reactions/comments/subscription. We will extend `except:` to also
  exclude `:show`.
- `app/views/journal_entries/show.rb` (184 lines) — will be **deleted**.
  Its render logic (hero → action bar → details → body → images → reactions
  → comments) is folded into the expandable card.
- `app/components/journal_entry_card.rb:75-82` — "Read more →" is a
  `link_to trip_journal_entry_path`. Replaces with a Stimulus-driven
  `<details>`/Turbo Frame expansion.
- `app/controllers/journal_entries_controller.rb:36,52,63` — create/update/
  destroy redirect to `[@trip, entry]` (show page). All three must redirect
  to the trip show with a fragment anchor.
- `app/controllers/comments_controller.rb:118` — Turbo Stream appends to
  `comments_#{@journal_entry.id}`. This DOM ID must be preserved inside the
  expanded card so existing streams keep working.
- `app/controllers/reactions_controller.rb:23` — Turbo Stream replaces
  `reaction_summary_#{@journal_entry.id}`. Same requirement — DOM id must
  exist inside the expanded card.
- `spec/system/journal_entries_spec.rb` — Capybara flows currently navigate
  to the show page. Will be rewritten to exercise the feed.

---

## Implementation Tasks

### Task 1 — Kanban & Issue

1. Create GitHub issue on `joel/trip` titled
   **"Phase 15 — Convert Journal Entries to inline feed wall"** with body
   linking to this plan file.
2. Label: `feature`.
3. Move issue through Kanban: Backlog → Ready → In Progress.
4. Assign self.

### Task 2 — Model: add reverse chronological scope

**File:** `app/models/journal_entry.rb`

Add:

```ruby
scope :reverse_chronological, -> {
  order(entry_date: :desc, created_at: :desc, id: :desc)
}
```

Keep `.chronological` — it's still used by MCP `list_journal_entries` and
exports. Do not change default behaviour of existing callers.

**Test:** extend `spec/models/journal_entry_spec.rb` with a scope test
mirroring the existing `.chronological` test.

### Task 3 — Trips controller: load newest first

**File:** `app/controllers/trips_controller.rb:20`

```ruby
@journal_entries = @trip.journal_entries
                        .reverse_chronological
                        .includes(:comments, :reactions, :author,
                                  images_attachments: :blob,
                                  journal_entry_subscriptions: :user)
```

Eager loading expanded so that card rendering (body, images, reactions,
comment count, per-user subscription check) stays N+1 free when every card
can render the full expanded state.

### Task 4 — Invert follow default in Create action

**File:** `app/actions/journal_entries/create.rb`

Replace `subscribe_author` with `subscribe_trip_members`:

```ruby
def call(params:, trip:, user:)
  entry = yield persist(params, trip, user)
  yield subscribe_trip_members(entry)
  yield emit_event(entry)
  Success(entry)
end

private

def subscribe_trip_members(entry)
  user_ids = entry.trip.members.pluck(:id) | [entry.author_id]
  rows = user_ids.map do |uid|
    { journal_entry_id: entry.id, user_id: uid,
      created_at: Time.current, updated_at: Time.current }
  end
  JournalEntrySubscription.insert_all(rows) if rows.any?
  Success()
rescue ActiveRecord::RecordNotUnique
  Success()  # idempotent — some members may already be subscribed
end
```

**Trip#members** — verify the association exists. If the project uses
`trip_memberships` (which `routes.rb:44-45` confirms), use:
`entry.trip.users` or `User.joins(:trip_memberships).where(trip_memberships: { trip: entry.trip })`.
Check `app/models/trip.rb` before writing the query.

**Failure mode to avoid:** if a user is removed from the trip later, the
subscription becomes stale. That is acceptable — the mute button is the
escape hatch, and notification delivery already checks membership at emit
time (Phase 11). Verify that assumption against
`app/subscribers/notifications_subscriber.rb` (or equivalent) before
shipping. If delivery does **not** gate on membership, add that check in
the notification subscriber rather than complicating this action.

**Test:** `spec/models/journal_entry_subscription_spec.rb` —
add a context "when a journal entry is created" that asserts every trip
member is subscribed, and the author is subscribed, and no duplicates
exist.

### Task 5 — Remove the show route, action, and view

**Files:**

- `config/routes.rb:29` — change to
  `resources :journal_entries, except: %i[index show] do`
- `app/controllers/journal_entries_controller.rb` — delete `show` action
  and remove `:show` from the `set_journal_entry`/`authorize_journal_entry!`
  `only:` filters.
- `app/views/journal_entries/show.rb` — **delete**.
- `app/policies/journal_entry_policy.rb` — remove `show?` if nothing else
  references it (grep first). If kept, have it delegate to `trip_policy.show?`.
- `spec/requests/journal_entries_spec.rb` — delete the `describe "GET show"`
  block (lines 11-17 and related authorization matrix rows).
- `spec/policies/journal_entry_policy_spec.rb` — delete `show?` specs.
- `spec/system/journal_entries_spec.rb` — will be rewritten in Task 10.

### Task 6 — Redirect create/update/destroy back to the feed

**File:** `app/controllers/journal_entries_controller.rb`

Replace the three redirects:

```ruby
# create success
redirect_to trip_path(@trip, anchor: "journal_entry_#{entry.id}"),
            notice: "Entry created."

# update success
redirect_to trip_path(@trip, anchor: "journal_entry_#{entry.id}"),
            notice: "Entry updated."

# destroy
redirect_to trip_path(@trip),
            notice: "Entry deleted.", status: :see_other
```

The card's outer `div` already has `id: dom_id(@entry)` which renders as
`journal_entry_<id>` — the anchor will line up.

### Task 7 — Refactor `JournalEntryCard` into an expandable feed item

**File:** `app/components/journal_entry_card.rb`

The card absorbs the full content of the former show page. Structure:

```
<article id="journal_entry_<id>" class="ha-card">
  <header>
    <overline>entry_date</overline>
    <h3>name</h3>
    <location + author_avatar + author_name>
    <mute_toggle (bell icon)>   ← Task 8
  </header>

  <summary>
    <image_carousel_preview if images.any?>
    <description line-clamp-2 when collapsed, line-clamp-none when expanded>
  </summary>

  <details data-controller="feed-entry" data-feed-entry-expanded-value="false">
    <button data-action="feed-entry#toggle">Read more ▾ / Collapse ▴</button>

    <div data-feed-entry-target="body" hidden>
      <prose body>
      <image grid (not just first)>
      <reactions#reaction_summary_<id>>
      <comments#comments_<id>>
      <comment form>
    </div>
  </details>

  <footer>
    <reaction count + comment count + "expand" link>
    <edit/delete actions if allowed_to?>
  </footer>
</article>
```

**Stimulus controller:** `app/javascript/controllers/feed_entry_controller.js`

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "label"]
  static values  = { expanded: Boolean }

  toggle() {
    this.expandedValue = !this.expandedValue
    this.bodyTarget.hidden = !this.expandedValue
    this.labelTarget.textContent = this.expandedValue ? "Collapse" : "Read more"
  }
}
```

Register it in `app/javascript/controllers/index.js` (follow existing
registration pattern — likely `eagerLoadControllersFrom` is already in
place).

**Do not** use the native `<details>` element: we need Turbo Stream
injections (new comments) to not close the panel on re-render, and we
need the feed to stay expanded across same-page Turbo visits.

**Critical DOM IDs to preserve** (used by existing Turbo Stream targets):

- `comments_<entry_id>` — the `<div>` wrapping the comments list
- `reaction_summary_<entry_id>` — `ReactionSummary` component root
- `<%= dom_id(comment) %>` — each rendered comment card

If these IDs are missing when the body is `hidden`, Turbo Streams still
work because the elements exist in the DOM (just not visible). Verify
in Task 11.

### Task 8 — Replace follow button with mute toggle on the card

**File:** `app/components/journal_entry_follow_button.rb`

Rename semantically (the class name can stay for git history, but rework
the UI):

- State 1 (subscribed, default): bell icon, tooltip "Mute notifications",
  `DELETE /trips/:tid/journal_entries/:id/subscription`
- State 2 (unsubscribed): bell-off icon, tooltip "Resume notifications",
  `POST /trips/:tid/journal_entries/:id/subscription`

Both buttons use Turbo Frames so they swap in place without reloading.
Wrap the button in `<turbo-frame id="journal_entry_<id>_mute">` so the
controller can respond with a Turbo Stream that replaces just the frame.

**Controller change:** `app/controllers/journal_entry_subscriptions_controller.rb`

Replace the redirects (lines 13, 20) with Turbo Stream responses that
replace the frame with the opposite-state button, plus HTML fallback
redirecting to the trip page anchor:

```ruby
def create
  @journal_entry.journal_entry_subscriptions
                .find_or_create_by!(user: current_user)
  respond_to do |format|
    format.turbo_stream { render_mute_button(subscribed: true) }
    format.html { redirect_to trip_path(@trip, anchor: dom_id(@journal_entry)) }
  end
end
```

Icons: use the existing icon components under `app/components/icons/`.
If `Bell` / `BellOff` don't exist yet, add them (8-12 lines each, stroke
style, follow the pattern of `app/components/icons/plus.rb`).

### Task 9 — Subscriptions spec update

**File:** `spec/requests/journal_entry_subscriptions_spec.rb`

- Remove assertions that expect a redirect to the show page.
- Add assertions that the response is `turbo_stream` format and contains
  the opposite-state button.
- Add a request spec covering the "author is already subscribed after
  create" scenario, as well as "another trip member is auto-subscribed".

### Task 10 — System spec rewrite

**File:** `spec/system/journal_entries_spec.rb`

Rewrite Capybara flows. No navigation to entry show page; assertions
are on the trip show page only.

Scenarios:

1. **Create → appears at top of feed**
   Create a trip with two entries already (different entry_dates).
   Create a new entry, assert the newly created entry is the first
   card on the trip page.

2. **Expand in place**
   Click "Read more" on the second card. Assert the body, images, and
   comments appear without URL change. Assert `current_path` is still
   `trip_path(@trip)`.

3. **Inline comment**
   Expand a card, submit a comment, assert the comment shows up in the
   same card (no page reload).

4. **Inline reaction**
   Expand, click a reaction emoji, assert the count increments in the
   same card.

5. **Auto-follow on create**
   User A creates an entry in a trip shared with User B. Sign in as
   User B, visit the trip, assert the entry's mute toggle shows the
   "muted available" state (i.e., currently subscribed).

6. **Mute from feed**
   Click the bell icon on a card, assert the icon swaps to bell-off
   without navigation.

7. **Delete from expanded card**
   Expand, click Delete, confirm, assert redirect back to trip page
   and the card is gone.

### Task 11 — Turbo Stream regression check

Manual verification (no automation — Turbo Streams are painful to test
from RSpec):

- Create a comment on an entry whose card is **collapsed**. The comment
  should still be appended to the hidden `comments_<id>` container; when
  the user expands, it should be visible. Document in the PR description.
- Add a reaction on a collapsed card — the count in the footer should
  update (the `reaction_summary_<id>` frame is re-rendered inside the
  expanded area, so the footer count needs its own small target or it
  needs to read from the same frame). **Decision:** the footer count
  lives outside the expandable body as a `<span id="reaction_count_<id>">`
  that the reactions controller ALSO streams. Update
  `app/controllers/reactions_controller.rb` to stream both targets.

### Task 12 — Run lint + tests

```bash
bundle exec rake project:fix-lint
bundle exec rake project:lint
bundle exec rake project:tests
bundle exec rake project:system-tests
```

Fix any failures. No `OVERCOMMIT_DISABLE=1`. If a hook false-positives,
use `SKIP=<HookName>` and document in the commit body.

### Task 13 — Runtime verification

Per `AGENTS.md` section 5:

```bash
bin/cli app rebuild
bin/cli app restart
bin/cli mail start
```

Use `agent-browser` at `https://catalyst.workeverywhere.docker/` to walk
through:

- Sign in as a superadmin.
- Visit a trip with several entries → verify newest is first, all cards
  collapsed by default.
- Click "Read more" on a card → verify body, images, reactions, comments
  appear inline.
- Write a comment → verify it appears in the same card with no navigation.
- Click a reaction → verify count increments.
- Click the bell icon → verify it swaps to muted state with no navigation.
- Create a new entry → verify the redirect lands on the trip page with
  the new card at the top and page scroll jumping to the anchor.
- Sign in as a second trip member (via MailCatcher-verified account) →
  verify the new entry shows as "subscribed by default" on their view.
- Verify `/journal_entries/:id` is a 404.

### Task 14 — Commit strategy

Atomic commits per
`memory/feedback_atomic_commits.md`. Suggested breakdown:

1. `feat(journal): add reverse_chronological scope`
2. `refactor(trips): load journal entries newest first with eager loads`
3. `feat(journal): auto-subscribe trip members on entry creation`
4. `refactor(routes): remove journal_entries#show`
5. `feat(journal): fold entry body into expandable feed card`
6. `feat(journal): add Stimulus feed_entry controller for inline expand`
7. `feat(journal): mute toggle replaces follow button on feed card`
8. `refactor(journal): redirect CRUD back to trip feed anchor`
9. `test(journal): rewrite system specs for feed wall`
10. `test(journal): update request specs for removed show + new subscribe defaults`

Each commit passes `bundle exec rake project:lint` on its own.

### Task 15 — PR + Kanban

1. Push branch `feature/phase-15-feed-wall`.
2. Open PR against `main` with a description linking to this plan and
   listing the runtime verification screenshots.
3. Move issue to **In Review**.
4. Respond to every review comment per `AGENTS.md` section 4.

---

## Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Feed renders slowly on trips with 50+ entries | Eager loads in Task 3; benchmark before PR; if >300ms flag for pagination follow-up |
| Auto-subscribing all trip members floods inbox | Notifications already batch at delivery (Phase 11); verify before merge that the in-app notification subscriber dedupes per-user |
| Stimulus controller not loaded in production | Verify `app/javascript/controllers/index.js` auto-registration pattern — catalyst already ships Stimulus so this should be routine |
| Turbo Stream targets missing when card collapsed | Targets exist in the DOM (just `hidden`); documented in Task 11 |
| Removing the show route breaks a deep link someone bookmarked | The show URL was never shared externally (no marketing surface); acceptable. If needed later, add a redirect from `/trips/:tid/journal_entries/:id` → `/trips/:tid#journal_entry_<id>` |
| Existing journal entries created before this phase have no subscribers | Write a one-off rake task `rake journal_entries:backfill_subscriptions` that subscribes every trip member to every existing entry. Run once post-deploy, then delete the rake file in a follow-up PR |
| MCP `create_journal_entry` tool behaviour changes (Jack becomes subscriber to everything) | Jack is `jack@system.local`, a system actor — being auto-subscribed is inert (no notification delivery target). Confirm Jack is filtered out of trip.members before inserting subscriptions, OR accept the rows since they cost nothing |

## Out-of-scope follow-ups to file as separate issues

- Pagination / infinite scroll for the feed when entries > 50.
- Keyboard shortcut (`j`/`k`) to move between expanded entries.
- Sticky mini-header showing the entry date as the user scrolls.
- "Jump to date" control in the trip page sidebar.

---

## Acceptance criteria (checklist)

- [ ] `/trips/:id/journal_entries/:id` returns 404.
- [ ] Trip show page lists entries newest first.
- [ ] Every card starts collapsed; "Read more" expands in place with zero
      navigation.
- [ ] Inline comment form in the expanded card works via Turbo Streams.
- [ ] Inline reaction buttons in the expanded card work via Turbo Streams.
- [ ] Mute toggle (bell icon) sits on every card, swaps state via Turbo
      Streams without page reload.
- [ ] New entries auto-subscribe every trip member; the author is
      included.
- [ ] Existing entries are backfilled with subscriptions for every trip
      member.
- [ ] `journal_entries/show.rb` view is deleted.
- [ ] `bundle exec rake project:tests` and `bundle exec rake project:system-tests`
      both pass locally.
- [ ] Runtime verification at `https://catalyst.workeverywhere.docker/`
      passes for all scenarios in Task 13.
- [ ] No `OVERCOMMIT_DISABLE=1`; any `SKIP=Hook` documented in commit body.
- [ ] Google Stitch design in `prompts/Phase 15 - Feed Wall Design Prompt.md`
      reviewed and the generated screens applied to the UI polish pass.
