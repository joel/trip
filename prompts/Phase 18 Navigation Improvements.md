# Phase 18: Navigation Improvements

```
claude --resume f0ae9582-92a7-4d52-b543-4f3126efc417
```

**Status:** Draft — product decisions resolved (see §8)
**Date:** 2026-04-19
**Confidence Score:** 9/10 (all four open questions answered; scope is fully concrete)

---

## 1. Context

Three independent navigation/IA bugs surfaced in live use after the Phase 17 passkey + redirect work:

1. **Mobile users cannot sign out.** The desktop sidebar (`app/components/sidebar.rb:12`) is `hidden md:flex`, so its "Sign out" button (`render_logout_button`, lines 180-191) is invisible below the `md:` breakpoint. The mobile chrome (`MobileTopBar` + `MobileBottomNav`) has no logout entry point. The Profile tab on mobile lands on `/account` — but `Views::Accounts::Show` (`app/views/accounts/show.rb:14-33`) renders only "Edit account" + "Delete account". A mobile-only user is stuck signed in.

2. **Trip viewers see contributor-only nav buttons.** On `/trips/:id`, the action bar (`app/views/trips/show.rb:89-124`) shows three secondary buttons — **Members**, **Checklists**, **Exports** — for any trip member. The `viewer` role is a read-only persona (e.g. a family member who shouldn't manage permissions, edit checklists, or trigger heavy export jobs). Two of the three buttons (Members, Checklists) render unconditionally with no `allowed_to?` guard. The third (Exports) is gated by `ExportPolicy.index?` which currently accepts any member.

3. **Logged-in `/` is empty filler.** Phase 17 moved `login_redirect`, `create_account_redirect`, and `webauthn_setup_redirect` to `/trips` (`app/misc/rodauth_main.rb:71-73`). The "Overview" link in the sidebar and the "Home" tab on mobile both still point at `/`, which now renders a hero greeting + a single "Stay connected" admin card (`app/views/welcome/home.rb:18-156`). For a non-admin user mid-trip, that page is dead weight. The user wants `/` to land them inside their **current ongoing trip**.

None of these touch auth, MCP, schema, or data. This phase is pure routing + view + one policy tightening.

---

## 2. Reference Documentation

| Resource | URL |
|----------|-----|
| Rodauth `logout` feature | https://rodauth.jeremyevans.net/rdoc/files/doc/logout_rdoc.html |
| ActionPolicy `allowed_to?` in views | https://actionpolicy.evilmartians.io/#/rails?id=in-views |
| ActionPolicy custom policies via `with:` | https://actionpolicy.evilmartians.io/#/policies?id=resolution-rules |
| Rails 8.1 controller `redirect_to` | https://api.rubyonrails.org/v7.0/classes/ActionController/Redirecting.html |
| Phlex Rails `button_to` helper | https://www.phlex.fun/rails/helpers |
| Tailwind CSS 4 docs | https://tailwindcss.com/docs |

---

## 3. Scope

### What this phase changes

1. **Mobile-accessible logout.** Add a "Sign out" `button_to` on `Views::Accounts::Show` (the page the mobile Profile tab already lands on). Visible on every viewport so desktop and mobile users get a single consistent affordance.
2. **Hide Members / Checklists / Exports from viewers.**
   - Tighten `TripMembershipPolicy.index?`, `ChecklistPolicy.index?`/`show?`, and `ExportPolicy.index?` so a `viewer` membership does not satisfy them.
   - Wrap each of the three buttons in `app/views/trips/show.rb` with the matching `allowed_to?` check so the UI follows the policy.
3. **`/` (Overview / Home) becomes a smart router.** The Overview / Home nav entries **stay** — they're now genuinely useful because `/` routes to the right place per user state:
   - **0 trips** → render an empty-state screen ("No trips yet! Don't worry, a new one will be added in no time").
   - **1 trip** → redirect to that trip's show page.
   - **2+ trips, ≥1 in `started` state** → redirect to the most recently updated `started` trip.
   - **2+ trips, none `started`** → redirect to `/trips` index (inferred fallback — user didn't specify; this is the only sensible non-loop option).
   - The "Trips" tab continues to point at `/trips` index unchanged — it's the explicit "show me everything" entry, distinct from the smart `/` router.

### What this phase does NOT change

- No schema changes, no migrations.
- No change to `login_redirect` or any Rodauth redirect (Phase 17 already settled those).
- No change to the desktop sidebar's "Sign out" button (it stays — the new Account-page button is additive, not a replacement).
- No change to the contributor / superadmin trip views — they keep all three buttons.
- No change to the underlying `journal_entries`, `comments`, `reactions` policies (viewer can still read journal feed and react/comment per current policies).
- No change to MCP, notifications, exports background processing, or any controller other than `WelcomeController` (and the three policy files).
- No change to `logout_redirect` — it still lands on `/`, which now renders the empty state for users with zero trips and the welcome screen for logged-out users.

---

## 4. Existing Codebase Context

### Relevant files

| File | Current behaviour |
|------|-------------------|
| `app/components/sidebar.rb:12` | Root `<nav>` is `hidden md:flex`. Logout button at `:180-191` is desktop-only. |
| `app/components/mobile_top_bar.rb:7-21` | Header with title + theme toggle + avatar (links to `/account`). No logout. |
| `app/components/mobile_bottom_nav.rb:7-29` | Five tabs: Home, Trips, Notifs, Users (admins only), Profile (→ `/account`). No logout. |
| `app/views/accounts/show.rb:14-33` | Renders Edit / Delete account buttons. No Sign-out CTA. |
| `app/views/trips/show.rb:89-124` | `render_action_bar` always shows Members + Checklists; gates Exports via `allowed_to?(:index?, @trip, with: ExportPolicy)`; gates Edit / Delete / Transition via their own policies. |
| `app/policies/trip_membership_policy.rb:4-6` | `index? = superadmin? || member_of_trip?` (any membership). |
| `app/policies/checklist_policy.rb:4-10` | `index? = superadmin? || member?`; `show?` likewise. |
| `app/policies/export_policy.rb:4-6` | `index? = superadmin? || member?`. |
| `app/policies/trip_policy.rb:48-50` | `contributor?` helper already exists — uses `trip_membership&.contributor?`. Pattern to mirror in the other three. |
| `app/controllers/welcome_controller.rb:3-7` | One-line action that renders `Views::Welcome::Home.new`. |
| `app/views/welcome/home.rb:190-195` | `active_trip` helper already computes `user.trips.find_by(state: :started)`. The redirect logic can use the same query. |
| `app/misc/rodauth_main.rb:71-73` | Confirms `/trips` is the post-auth landing — Phase 18 is consistent with it. |

### Rails / project conventions worth citing

- **Phlex `button_to`.** Already used on the account page (`app/views/accounts/show.rb:22-27`) and the sidebar (`app/components/sidebar.rb:181-191`). Use the same pattern for the new Sign-out button: `method: :post`, `form: { class: "inline-flex" }`, `class: "ha-button ha-button-secondary"`.
- **`ha-button` + `ha-button-*` design tokens.** Already compiled into the Tailwind CSS bundle. No new utility classes needed → no Docker rebuild required for CSS.
- **Policy `member?` vs `contributor?`.** The codebase already distinguishes them. This phase replaces `member?` with `contributor?` (or `superadmin? || contributor?`) in three policy methods so viewers fall through.
- **`allowed_to?` in Phlex views.** Pattern is `view_context.allowed_to?(:action?, record [, with: SomePolicy])`. Already used in `app/views/trips/show.rb:91, 101, 107, 161, 213`.
- **`redirect_to` from a controller action.** Standard Rails. Use `redirect_to trip_path(active_trip)` or `redirect_to trips_path`. No need for `status:` override — default 302 is fine for an idempotent GET.

---

## 5. Implementation Plan

### Task 1 — Mobile-accessible Sign out on the Account page

**File:** `app/views/accounts/show.rb`

In the `PageHeader`'s action slot (around lines 20-27), insert a Sign-out `button_to` between Edit and Delete. Use the secondary button style so Delete keeps its danger emphasis:

```ruby
link_to("Edit account", view_context.edit_account_path,
        class: "ha-button ha-button-secondary")
button_to("Sign out", view_context.rodauth.logout_path,
          method: :post,
          form: { class: "inline-flex" },
          class: "ha-button ha-button-secondary")
button_to("Delete account", view_context.account_path,
          method: :delete,
          class: "ha-button ha-button-danger",
          form: { class: "inline-flex" },
          data: { turbo_confirm: "Delete your account permanently?" })
```

No layout/breakpoint logic required — the button is visible everywhere, which keeps the contract simple ("Sign out lives on My account").

**No change** to `MobileTopBar`, `MobileBottomNav`, or `Sidebar` in this phase. The account page already exists, the mobile Profile tab already routes to it, and adding a button there is the smallest correct fix.

### Task 2 — Hide Members / Checklists / Exports from viewers

#### 2a. Policy tightening

**File:** `app/policies/trip_membership_policy.rb`

```ruby
def index?
  superadmin? || contributor_of_trip?
end

private

def contributor_of_trip?
  return false unless user

  record.trip.trip_memberships.exists?(user: user, role: :contributor)
end
```

(Drop `member_of_trip?` if unused after this change; otherwise keep.)

**File:** `app/policies/checklist_policy.rb`

Replace the `member?` helper's body so it returns true only for contributors, **or** change the two methods explicitly:

```ruby
def index?
  superadmin? || contributor?
end

def show?
  superadmin? || contributor?
end
```

Leave the existing `contributor?` private helper as-is (it already returns true only for `trip_membership&.contributor?`).

**File:** `app/policies/export_policy.rb`

```ruby
def index?
  superadmin? || contributor?
end

private

def contributor?
  trip_membership&.contributor?
end
```

(Mirror the helper from `trip_policy.rb`.)

#### 2b. UI buttons follow policy

**File:** `app/views/trips/show.rb`

In `render_action_bar` (lines 89-124), wrap Members and Checklists with the matching `allowed_to?` check (Exports already has one):

```ruby
if view_context.allowed_to?(:index?, @trip.trip_memberships.new)
  link_to("Members",
          view_context.trip_trip_memberships_path(@trip),
          class: "ha-button ha-button-secondary")
end
if view_context.allowed_to?(:index?, @trip.checklists.new)
  link_to("Checklists",
          view_context.trip_checklists_path(@trip),
          class: "ha-button ha-button-secondary")
end
if view_context.allowed_to?(:index?, @trip, with: ExportPolicy)
  link_to("Exports",
          view_context.trip_exports_path(@trip),
          class: "ha-button ha-button-secondary")
end
```

The `.new` instances are throwaway — `allowed_to?` only needs the policy class, which it derives from the record. Standard ActionPolicy pattern, already used by the existing Exports gate.

**Note on action bar collapse.** For a viewer, the action bar then renders only "Back to trips" (no Edit/Delete/Transition either, since those are already gated). Visually fine — the row stays balanced because of `flex flex-wrap gap-3`.

### Task 3 — Smart-router `/` + empty-state screen

**File:** `app/controllers/welcome_controller.rb`

```ruby
class WelcomeController < ApplicationController
  def home
    if (target = post_login_target_for(current_user))
      redirect_to(target) and return
    end
    render Views::Welcome::Home.new
  end

  private

  def post_login_target_for(user)
    return unless user

    trips = user.trips
    count = trips.count
    return nil if count.zero?
    return trip_path(trips.first) if count == 1

    started = trips.where(state: :started).order(updated_at: :desc).first
    started ? trip_path(started) : trips_path
  end
end
```

**Branches:**
- Logged in + **zero** trips → fall through to empty-state render.
- Logged in + **one** trip → that trip's show page.
- Logged in + **2+ trips, at least one `started`** → most recently updated `started` trip.
- Logged in + **2+ trips, none `started`** → `/trips` index (inferred fallback; user didn't specify but this avoids a loop and gives the user a picker).
- Logged out → falls through (`current_user` is nil) → existing welcome screen with "Request Access".

Two cheap SQL hits worst case: `COUNT(*)` on the user's trips, then a `WHERE state = 'started' ORDER BY updated_at DESC LIMIT 1`. Acceptable per request.

**Multiple started trips note.** The plan picks the most recently updated `started` trip. The user flagged a follow-up idea — a policy enforcing only one started trip at a time, with friendly "finish/archive your current trip first" messaging. **Deferred** out of this phase (it's a behavioural constraint with its own validation + UX surface). The `order(updated_at: :desc).first` heuristic is the V1 stopgap; if a user complains the wrong trip wins, the deferred policy is the proper fix.

**File:** `app/views/welcome/home.rb`

Replace `render_logged_in_dashboard` with a small empty-state block. The hero greeting stays (friendly), the "Continue Trip" / active-trip-card / "Stay connected" admin card all go (they're vestigial once the redirect logic runs):

```ruby
def render_logged_in_dashboard
  div(class: "mx-auto w-full max-w-md space-y-8 text-center") do
    section do
      h1(class: "font-headline text-4xl font-bold tracking-tighter md:text-5xl") do
        plain "Welcome, #{user_first_name}"
      end
      p(class: "mt-4 text-lg text-[var(--ha-on-surface-variant)]") do
        plain "No trips yet! Don't worry, a new one will be added in no time."
      end
    end
    if view_context.allowed_to?(:create?, Trip)
      div do
        link_to(view_context.new_trip_path, class: "ha-button ha-button-primary") do
          render Components::Icons::Plus.new(css: "h-5 w-5")
          plain "New Trip"
        end
      end
    end
  end
end
```

Delete `render_quick_actions`, `render_active_trip_section`, `render_trip_hero_image`, `render_trip_details`, `render_trip_stats`, `stat_card`, `render_info_cards`, `render_users_card`, `active_trip` — all dead once the dashboard is just the empty-state. Keep `user_first_name` (used by the hero) and `render_logged_out` / `render_access_card` (still used for logged-out path).

### Task 4 — Tests

#### Request specs

**File:** `spec/requests/welcome_spec.rb` (new or extend existing)

- `GET /` when logged out → renders welcome page, status 200.
- `GET /` when logged in with **zero** trips → renders empty-state page (status 200, body contains "No trips yet").
- `GET /` when logged in with **one** trip (any state) → 302 to `/trips/<id>`.
- `GET /` when logged in with **2+ trips, exactly one `started`** → 302 to that started trip.
- `GET /` when logged in with **2+ trips, multiple `started`** → 302 to the started trip with the most recent `updated_at`.
- `GET /` when logged in with **2+ trips, none `started`** → 302 to `/trips`.

**File:** `spec/policies/trip_membership_policy_spec.rb` (new or extend)

- viewer member: `index?` is **false**.
- contributor member: `index?` is **true**.
- superadmin (non-member): `index?` is **true**.
- non-member: `index?` is **false**.

**File:** `spec/policies/checklist_policy_spec.rb` (new or extend)

- viewer member: `index?`, `show?` are **false**.
- contributor member: `index?`, `show?` are **true**.
- (Existing create/edit/destroy specs unchanged — they were already contributor-gated.)

**File:** `spec/policies/export_policy_spec.rb` (new or extend)

- viewer member: `index?` is **false** (was `true` before this phase).
- contributor member: `index?` is **true**.

#### System specs

**File:** `spec/system/accounts_spec.rb` (extend)

- Account show page renders a "Sign out" button.
- Clicking it logs the user out and redirects to `/` (Rodauth's `logout_redirect`).

**File:** `spec/system/trips_spec.rb` (extend) **or** `spec/system/trip_viewer_visibility_spec.rb` (new)

- Logged in as a viewer of a trip, visiting `/trips/:id`:
  - **No** "Members" button visible.
  - **No** "Checklists" button visible.
  - **No** "Exports" button visible.
  - Direct `GET /trips/:id/trip_memberships` → 403/redirect (whichever ActionPolicy is configured to do here).
  - Direct `GET /trips/:id/checklists` → 403/redirect.
  - Direct `GET /trips/:id/exports` → 403/redirect.
- Logged in as a contributor of the same trip:
  - All three buttons are visible.
  - Direct GETs all return 200.

**File:** `spec/system/welcome_spec.rb` (extend)

- Visiting `/` as a logged-in user with **one** trip lands on that trip's show page.
- Visiting `/` as a logged-in user with **2+ trips and one `started`** lands on the started trip.
- Visiting `/` as a logged-in user with **2+ trips and none `started`** lands on `/trips`.
- Visiting `/` as a logged-in user with **no** trips shows the empty-state hero with copy "No trips yet! Don't worry, a new one will be added in no time."
- Desktop sidebar still shows "Overview" as the first nav item; clicking it follows the smart-router rules.
- Mobile bottom nav still shows "Home" as the first tab; tapping it follows the smart-router rules.

---

## 6. Files to Modify

| File | Change |
|------|--------|
| `app/views/accounts/show.rb` | Add Sign-out `button_to` (Task 1) |
| `app/policies/trip_membership_policy.rb` | `index?` requires contributor or superadmin (Task 2a) |
| `app/policies/checklist_policy.rb` | `index?` / `show?` require contributor or superadmin (Task 2a) |
| `app/policies/export_policy.rb` | `index?` requires contributor or superadmin (Task 2a) |
| `app/views/trips/show.rb` | Wrap Members / Checklists / Exports buttons in `allowed_to?` (Task 2b) |
| `app/controllers/welcome_controller.rb` | Smart-router redirect logic for `/` (Task 3) |
| `app/views/welcome/home.rb` | Replace logged-in dashboard with empty-state screen; drop dead helpers (Task 3) |
| `spec/system/accounts_spec.rb` | Sign-out coverage (Task 4) |
| `spec/system/welcome_spec.rb` | Smart-router cases + empty-state copy (Task 4) |
| `spec/system/trips_spec.rb` *(or new viewer spec)* | Viewer hides Members/Checklists/Exports (Task 4) |
| `spec/policies/trip_membership_policy_spec.rb` | Viewer denial (Task 4) |
| `spec/policies/checklist_policy_spec.rb` | Viewer denial (Task 4) |
| `spec/policies/export_policy_spec.rb` | Viewer denial (Task 4) |

## 7. Files to Create

None required. (The three policy specs may not exist yet — if so, treat them as new files following the pattern of any existing policy spec.)

---

## 8. Product Decisions (resolved)

| # | Question | Decision |
|---|----------|----------|
| 1 | Sign-out placement | **Account show page** (button next to Edit / Delete). Confirmed default. |
| 2 | Viewer access scope for Members / Checklists / Exports | **Hide UI + deny in policy** for all three (option b). Checklists included — viewers don't need them. |
| 3 | Behaviour when user has zero trips | **Render an empty-state screen** with the copy: *"No trips yet! Don't worry, a new one will be added in no time."* Admins still see a "New Trip" CTA on this screen (gated by `allowed_to?(:create?, Trip)`); non-admins just see the message. |
| 4 | "Overview" / "Home" nav entries | **Keep both.** `/` becomes a smart router (see redirect rules below), so the entries are useful again. "Trips" tab continues to point at `/trips` index — it's the explicit "show me everything" entry, distinct from the smart `/`. |

**Smart-router rules for `/` (revised, supersedes earlier trip-count-only logic):**
- 0 trips → empty-state screen.
- 1 trip → that trip's show page.
- 2+ trips with **at least one `started`** → most recently updated `started` trip.
- 2+ trips with **none `started`** → `/trips` index (inferred fallback; user didn't specify).

**Deferred:** a model-level constraint that only one trip can be `started` per user at a time (with friendly "finish or archive your current trip first" UX). Out of scope for Phase 18 because it's a behavioural rule with its own validation surface and migration considerations. Tracked as a follow-up; the `order(updated_at: :desc).first` heuristic above is the V1 stopgap.

---

## 9. Risks

1. **Viewer policy tightening could break a flow we haven't thought of.** E.g. a viewer following a deep link to a checklist they were referenced in. Mitigation: the system specs in Task 4 explicitly cover viewer access for all three resources; if a flow breaks, it surfaces in CI.

2. **Redirect on `/` could create a loop.** If `trip_path(active_trip)` itself redirects back to `/` for some reason (it doesn't today, but defensive), we'd loop. Mitigation: the controller uses `and return` on each branch and only one branch fires per request. Trip show is a normal `render`, not a redirect. Risk is theoretical, but worth a system test that explicitly hits `/` and asserts a single redirect.

3. **Multiple `started` trips ordering.** When a user has 2+ trips in `started` state, picking by `updated_at` desc means an entry comment on Trip A bumps it above Trip B — even if the user mentally considers Trip B "the one I'm on right now". Mitigation: this is the V1 heuristic; the proper fix is the deferred "only one started trip at a time" constraint (see §8). For now the worst case is one extra click from the destination trip back to `/trips` to pick the right one.

4. **Account page Sign-out alongside Delete.** Two destructive-feeling buttons next to each other invites a misclick. Mitigation: Sign-out is `ha-button-secondary` (neutral), Delete keeps `ha-button-danger` (red). The visual hierarchy is clear; Delete already requires `turbo_confirm`.

5. **Tailwind JIT.** All three buttons use `ha-button` + `ha-button-secondary` / `ha-button-danger`, all compiled. **No** Docker rebuild required for CSS reasons. `bin/cli app rebuild` is still mandatory for `/product-review` to pick up the controller / view changes in the running container.

---

## 10. Verification

### Pre-commit (local)

```bash
mise x -- bundle exec rake project:fix-lint
mise x -- bundle exec rake project:lint
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
```

### Runtime Verification (per `/product-review` skill)

```bash
bin/cli app rebuild
bin/cli app restart
bin/cli mail start
```

Then with `agent-browser` against `https://catalyst.workeverywhere.docker/`:

**Mobile viewport (≤768px), logged in**
- [ ] Profile tab → `/account` shows "Sign out" button alongside Edit + Delete
- [ ] Tapping Sign out logs the user out and lands on `/`
- [ ] Mobile sidebar is still hidden (no regression)

**Desktop viewport, logged in**
- [ ] Account show page now also shows Sign out (in addition to sidebar Sign out)
- [ ] Sidebar Sign out still works

**Trip view as a viewer**
- [ ] `/trips/:id` action bar shows **only** "Back to trips" (no Members, Checklists, Exports, Edit, Delete, Transition)
- [ ] Direct GET `/trips/:id/trip_memberships` → forbidden (303 to safe page or 403)
- [ ] Direct GET `/trips/:id/checklists` → forbidden
- [ ] Direct GET `/trips/:id/exports` → forbidden
- [ ] Viewer can still see the journal feed, react, and comment (no regression)

**Trip view as a contributor**
- [ ] All three buttons (Members, Checklists, Exports) visible
- [ ] All three pages render normally

**Logged-in `/` smart router**
- [ ] User with **zero** trips → renders the empty-state screen with the "No trips yet…" copy
- [ ] Empty-state screen shows a "New Trip" CTA for admins, no CTA for non-admins
- [ ] User with **one** trip → lands on `/trips/<id>`
- [ ] User with **2+ trips, one `started`** → lands on the started trip
- [ ] User with **2+ trips, multiple `started`** → lands on the most recently updated started trip
- [ ] User with **2+ trips, none `started`** → lands on `/trips`
- [ ] Logged out → renders the existing welcome screen with "Request Access"

**Sidebar / mobile nav (unchanged in this phase)**
- [ ] Desktop sidebar still shows "Overview" as the first nav item; clicking it follows the smart-router rules
- [ ] Mobile bottom nav still shows "Home" as the first tab; tapping it follows the smart-router rules
- [ ] "Trips" tab (both desktop and mobile) continues to point at `/trips` index
- [ ] Tapping the brand title in `MobileTopBar` (still links to `/`) follows the smart-router rules

### Security Gates (per `/security-review` skill)

```bash
mise x -- bundle exec brakeman --no-pager
mise x -- bundle exec bundle-audit check --update
```

Pay particular attention to:
- The three policy changes — the new logic must not accidentally widen access (e.g. `superadmin? || contributor?` is correct; `superadmin? && contributor?` would lock superadmins out).
- The redirect logic — `redirect_to trip_path(active_trip)` must be on a record we know the user is a member of (`current_user.trips` already scopes it). Confirm the query uses the membership scope, not `Trip.where(state: :started)`.
- No `unsafe_raw` introduced anywhere.

### GitHub Workflow (per `/execution-plan` skill)

1. Open issue on [Trip Issues](https://github.com/joel/trip/issues): **"Phase 18: Navigation Improvements"**, link this plan.
2. Labels: `feature`, `cleanup`, `ux`.
3. Backlog → Ready → In Progress on [Trip Kanban Board](https://github.com/users/joel/projects/2/views/1).
4. Branch: `feature/phase18-navigation`.
5. One PR, three logical commits (see §11). All touch runtime code → **no `[skip ci]`**.
6. On PR open → In Review. Respond to every review comment, resolve every conversation.

---

## 11. Task Order (one PR, atomic commits per concern)

1. **Commit 1** — Add Sign-out `button_to` to Account show + accounts system spec (Task 1 + Task 4 accounts coverage).
2. **Commit 2** — Tighten three policies + wrap three buttons in `allowed_to?` + viewer/contributor visibility + policy specs (Task 2 + Task 4 viewer/policy coverage).
3. **Commit 3** — `WelcomeController#home` smart router + new empty-state in `welcome/home.rb` + welcome system + request specs (Task 3 + Task 4 welcome coverage).

Each commit is independently reversible; each touches runtime code so all three carry CI.

---

## 12. Quality Checklist

- [x] Each reported issue is mapped to its own task and its own commit (3 tasks, 3 commits)
- [x] Every behaviour change has a matching spec (request + system + policy where relevant)
- [x] Validation gates are executable by project skills (lint, tests, `/product-review`, `/security-review`)
- [x] References existing Phlex / ActionPolicy / Rails patterns — no new abstractions introduced
- [x] No schema, no migration, no dependency change
- [x] Backwards-compatible where it counts: superadmins and contributors keep all current access
- [x] All four open product questions resolved in §8 — scope is fully concrete
