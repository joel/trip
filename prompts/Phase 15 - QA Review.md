# QA Review -- feature/phase-15-feed-wall

**Branch:** `feature/phase-15-feed-wall`
**Phase:** 15
**Date:** 2026-04-12
**Reviewer:** Claude (adversarial QA pass)

---

## Test Suite Results

- **Unit + request specs:** 572 examples, 0 failures, 2 pending
- **System tests:** 60 examples, 0 failures
- **Linting (RuboCop):** 423 files inspected, no offenses detected

---

## Acceptance Criteria

- [x] Journal entries display inline on the trip show page as expandable cards -- PASS
- [x] Entries are ordered newest first via `reverse_chronological` scope -- PASS
- [x] Cards expand/collapse in place via Stimulus `feed-entry` controller -- PASS
- [x] Mute/unmute toggle works via Turbo Stream (no full page reload) -- PASS
- [x] Auto-subscribe all trip members (contributors + viewers) when a new entry is created -- PASS
- [x] Author is always subscribed even if not a trip member -- PASS
- [x] `journal_entries#show` route is removed -- PASS
- [x] All redirects updated from `[@trip, @journal_entry]` to `trip_path(@trip, anchor: ...)` -- PASS
- [x] Notification card links updated to trip page with entry anchor -- PASS
- [x] Email URLs updated to trip page with entry anchor -- PASS
- [x] Edit page "Back" link updated to point to trip page -- PASS
- [x] Empty state renders when trip has no entries -- PASS
- [x] "New Entry" button respects `create?` policy (hidden for viewers, non-writable trips) -- PASS
- [x] Delete button is inside expanded body, protected by `destroy?` policy -- PASS
- [x] Edit link in header respects `edit?` policy -- PASS

---

## Defects (must fix before merge)

No blocking defects found.

---

## Edge Case Gaps (should fix or document)

### E1: Jack (system actor) gets auto-subscribed to entries created via MCP

**File:** `app/actions/journal_entries/create.rb:24-26`
**Details:** The `subscribe_trip_members` method subscribes `entry.trip.members | [entry.author_id]`. When the MCP `create_journal_entry` tool creates an entry, the author is `jack@system.local`. Jack is not a trip member, but gets subscribed via the author union. This means Jack will receive notification emails (e.g., when someone comments on the entry), which is wasteful since Jack is a system actor that doesn't read email.
**Risk if left unfixed:** Low. Jack receives emails that go nowhere. No user-facing impact, but adds noise to the mail queue.
**Recommendation:** Either exclude system actors from subscription (`user_ids.reject { |id| User.find(id).email.end_with?("@system.local") }`) or add a `system?` predicate to User and filter in the notification subscriber. Alternatively, document this as expected behavior if Jack should receive notifications for audit purposes.

### E2: Footer reaction/comment counts are N+1 queries per entry (not eager loaded)

**File:** `app/components/journal_entry_footer.rb:31,50`
**Details:** `JournalEntryFooter` calls `@entry.reactions.group(:emoji).count` and `@entry.comments.count` for every collapsed card on page load. These are aggregate SQL queries that cannot be solved by Rails `includes`. With 10 entries, this adds 20 extra queries to the trip show page. Bullet does not flag aggregate queries, so this passes tests silently.
**Risk if left unfixed:** Medium on trips with many entries. Performance degrades linearly. For typical trip sizes (5-15 entries), it's acceptable but not optimal.
**Recommendation:** Add counter caches (`reactions_count`, `comments_count`) to `journal_entries` table, or use a single preloading query. This is a follow-up optimization, not a blocker.

### E3: No error boundary in `subscribe_trip_members` if a user is deleted mid-operation

**File:** `app/actions/journal_entries/create.rb:23-31`
**Details:** `subscribe_trip_members` iterates user IDs and calls `find_or_create_by!`. If a user is deleted between the `pluck(:id)` call and the subscription creation, the FK constraint will raise `ActiveRecord::InvalidForeignKey`. Since this occurs AFTER the entry is already persisted (line 6), the entry exists but the event is never emitted and remaining members don't get subscribed. The `yield` in `call` will propagate the error, returning a Failure to the controller, which re-renders the form even though the entry was actually created.
**Risk if left unfixed:** Very low. This is a rare race condition that requires a user deletion happening in the milliseconds between pluck and insert. But the consequence (entry created without subscriptions or event) is inconsistent state.
**Recommendation:** Wrap the loop in a `rescue ActiveRecord::InvalidForeignKey => e` and skip the deleted user, or use `find_or_create_by` (without bang) and ignore nil results. Consider a follow-up ticket.

### E4: Stimulus controller doesn't guard `bodyTarget` and `labelTarget`

**File:** `app/javascript/controllers/feed_entry_controller.js:9-10`
**Details:** The `toggle()` method accesses `this.bodyTarget` and `this.labelTarget` without `has*Target` guards (unlike `previewTarget` and `chevronTarget` which are properly guarded). If either target is missing from the DOM (e.g., Turbo Stream replaces the card and removes a target), Stimulus will throw `Error: Missing target element "body"`.
**Risk if left unfixed:** Very low in practice since both targets are always rendered. But inconsistent defensive coding.
**Recommendation:** Add `has*Target` guards for consistency, or document that these targets are mandatory.

---

## Observations

- **Clean route removal.** All 27 changed files have been audited for dangling `trip_journal_entry_path` or `trip_journal_entry_url` references. Zero references to the removed show route remain in runtime code. Prompt/doc files contain historical references which is expected.

- **Eager loading is well-scoped.** `TripsController#show` eager loads `:author`, `:journal_entry_subscriptions`, and `images_attachments: :blob`. The subscription check in `JournalEntryCard#render_mute_toggle` uses a Ruby-level `.any?` with block, iterating the preloaded collection rather than hitting the DB. Good.

- **Mailer URLs are correct.** Both `entry_created` and `comment_added` mailer methods now use `trip_url(@trip, anchor: "journal_entry_#{@entry.id}")` which matches the new feed wall pattern.

- **Idempotent subscription handling.** Both the action (`find_or_create_by!`) and the controller (`find_or_create_by!` for create, `find_by&.destroy!` for destroy) handle duplicate/missing subscriptions gracefully.

- **Policy consistency.** The `JournalEntryPolicy#show?` is now only used for subscription authorization. Trip-level access (`TripPolicy#show?`) gates the entire feed wall. No authorization gap exists between the old per-entry show and the new inline feed.

- **MCP compatibility.** The `create_journal_entry` MCP tool uses `JournalEntries::Create` action, which now auto-subscribes all trip members. MCP-created entries integrate seamlessly with the feed wall.

- **`raw(safe(...))` for Action Text body.** This is the standard Phlex pattern for rendering rich text and is consistent with how the deleted show view handled it. Not a new security concern.

---

## Regression Check

- **Trip CRUD** -- PASS (routes, show page with feed, edit, delete all work)
- **Journal entries** -- PASS (create, edit, delete via feed wall; images, comments, reactions render in expanded card)
- **Authentication** -- PASS (no auth-related changes; `require_authenticated_user!` still gates all controllers)
- **Comments & reactions** -- PASS (redirects updated; Turbo Stream responses work; seeded data renders)
- **Notifications** -- PASS (notification card links updated to trip page with anchor)
- **MCP Server** -- PASS (no route-dependent changes in MCP tools; all tools use model lookups)

---

## MCP Server

Not directly tested via HTTP in this review (no Docker environment running), but code-level analysis confirms:

| Test | Expected | Actual (code review) |
|------|----------|---------------------|
| tools/list | 12 tools | No changes to tool registry |
| create_journal_entry (writable) | success + auto-subscribe members | Code path uses `JournalEntries::Create` which now auto-subscribes |
| create_journal_entry (locked) | "not writable" | Guard unchanged in `BaseTool.require_writable!` |
| update_journal_entry | success | No changes to update tool |
| No show route dependency | N/A | MCP tools use model IDs, not URL paths -- no impact from route removal |

---

## Mobile (393x852)

Not tested (no Docker/browser environment available). The card layout uses responsive Tailwind classes (`md:grid-cols-3`, `md:h-96`, `sm:-mx-10`). The feed wall uses `space-y-6` for card spacing. No obvious overflow risks from code review, but visual verification is recommended.

| Page | Overflow | Buttons | Touch Targets | Notes |
|------|----------|---------|---------------|-------|
| Trip show (feed) | Likely OK | N/A | Mute toggle is 40x40 (h-10 w-10) -- below 44px minimum | Verify visually |
| Entry card expanded | Unknown | N/A | N/A | Test with long description/comments |

---

## Summary

The feed wall implementation is solid. All tests pass (632 total: 572 unit/request + 60 system), linting is clean, and there are no dangling references to the removed show route. The code is well-structured with proper authorization, eager loading, and Turbo Stream integration.

The four edge case gaps identified are all low-risk and suitable for follow-up tickets rather than blocking the merge. The most actionable one is E1 (Jack system actor subscription), which is a simple filter to add.
