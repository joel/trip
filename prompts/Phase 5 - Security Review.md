# Security Review -- feature/phase-5-comments-reactions-checklists

**Date:** 2026-03-23
**Reviewer:** Claude Opus 4.6 (adversarial security pass)
**Scope:** `git diff main...HEAD` (82 files, +3750 lines)
**Branch:** `feature/phase-5-comments-reactions-checklists`

---

## Checklist Summary

| Category | Status |
|---|---|
| Authentication & Authorization | PASS (with 1 warning) |
| Input & Output | PASS (with 1 warning) |
| Data Exposure | PASS |
| Mass Assignment & Query Safety | PASS |
| Secrets & Configuration | PASS |
| Dependencies | N/A |

---

## Critical (must fix before merge)

No critical issues found. The previously identified IDOR in `ChecklistItemsController` and authorization gap in `ReactionsController#destroy` have both been fixed (commits `94317ff`, `0df72ba`).

---

## Warning (should fix or consciously accept)

### W-1: `params[:emoji]` bypasses strong parameters pattern

**File:** `app/controllers/reactions_controller.rb:14`
**Line:** `emoji: params[:emoji]`

The emoji value is read as a raw top-level param rather than through a `params.expect` / `params.require.permit` wrapper. Every other controller in this diff uses strong parameters consistently (`comment_params`, `checklist_params`, `checklist_item_params`, `checklist_section_params`).

**Why it matters:** While the `Reaction` model validates `inclusion: { in: ALLOWED_EMOJIS }`, the raw `params[:emoji]` could be an Array or Hash if the attacker sends `emoji[]=thumbsup` or `emoji[key]=value`. ActiveRecord's `find_by(emoji: ["thumbsup"])` silently converts to a SQL `IN` clause, and `create!(emoji: ["thumbsup"])` would fail validation -- but the inconsistency is unnecessary. Using strong params would coerce the value to a scalar string and reject structured input at the controller boundary.

**Suggested fix:** Add a private method:

```ruby
def reaction_params
  params.expect(:emoji)
end
```

Then use `emoji: reaction_params` in the create action. Alternatively, cast explicitly: `emoji: params[:emoji].to_s`.

**Risk if deferred:** Low. Model validation prevents persistence of invalid values. The `find_by` with an array would just return `nil` (no match), and the toggle would create a new reaction that fails validation. No data corruption or authz bypass is possible.

### W-2: `Reactions::Toggle` failure result silently swallowed

**File:** `app/controllers/reactions_controller.rb:10-16`

```ruby
def create
  Reactions::Toggle.new.call(
    reactable: @journal_entry, user: current_user, emoji: params[:emoji]
  )
  redirect_to [@trip, @journal_entry]
end
```

The return value (which can be `Failure(errors)`) is not pattern-matched. If an invalid emoji is submitted, the action returns `Failure` but the controller redirects without any error flash. The user sees a silent redirect with no feedback.

**Why it matters:** This is not a security vulnerability, but it violates the fail-fast principle and makes debugging harder. Every other controller in this diff pattern-matches the result.

**Suggested fix:** Pattern-match and show an alert flash on failure, consistent with `CommentsController`.

**Risk if deferred:** Cosmetic only. No security impact.

---

## Informational (no action required)

### I-1: Pre-existing `unsafe_raw` in journal entry body rendering

**File:** `app/views/journal_entries/show.rb:81`

```ruby
unsafe_raw @entry.body.to_s
```

This renders the journal entry's rich text body without escaping. It pre-dates this branch (exists on `main` at the same line). The body comes from `has_rich_text :body` (Action Text), which sanitizes HTML on input via Rails' built-in sanitizer. This is the standard Rails pattern for rendering rich text and is acceptable. No new `unsafe_raw`, `html_safe`, or `raw` usage was introduced by this branch outside of Rodauth templates.

### I-2: N+1 query potential in ReactionSummary component

**File:** `app/components/reaction_summary.rb:59`

`user_reacted?(emoji)` calls `@entry.reactions.exists?(user: current, emoji: emoji)` once per emoji (6 emojis). Combined with `reaction_counts` doing a `group(:emoji).count`, this results in 7 queries per journal entry show page. For a single-entry view this is acceptable. If reactions are ever rendered in a list context (e.g., journal entry index), this should be optimized with preloading.

### I-3: No rate limiting on comment/reaction creation

All mutation endpoints (create comment, toggle reaction, create checklist item) have no rate limiting. An authenticated malicious user could spam comments or toggle reactions rapidly. This is not a vulnerability in the traditional sense but could be used for abuse. Consider adding `Rack::Attack` throttling in a future phase.

### I-4: Checklist sections use parent checklist's policy

**File:** `app/controllers/checklist_sections_controller.rb:37`

```ruby
def authorize_checklist!
  authorize!(@checklist)
end
```

There is no `ChecklistSectionPolicy`. Instead, the controller authorizes against the parent `@checklist` record, which delegates to `ChecklistPolicy`. This is a valid pattern -- sections inherit the same permission model as their parent checklist (contributor + writable trip). The authorization is applied via `before_action` on both `create` and `destroy`. No gap exists.

### I-5: Comment card shows user email as fallback

**File:** `app/components/comment_card.rb:35`

```ruby
plain @comment.user.name || @comment.user.email
```

If a user has no `name` set, their email is displayed to all trip members. This is a minor privacy consideration. Emails are already visible to trip members in other contexts (membership list), so this is consistent with the existing information exposure model.

### I-6: Database constraints are properly enforced

All new tables use:
- UUID primary keys (consistent with project pattern)
- `null: false` constraints on foreign keys and required fields
- Unique index on reactions (`idx_reactions_uniqueness`) preventing duplicate emoji per user per reactable
- Foreign key constraints on all `belongs_to` associations

---

## Not applicable

| Category | Reason |
|---|---|
| Invitation/token flows | No new token-based flows introduced |
| File uploads | No new file upload handling; existing `has_many_attached :images` is unchanged |
| Secrets & Configuration | No new secrets, env vars, or credentials files in the diff |
| Dependencies | No new gems added to `Gemfile` or `Gemfile.lock` |
| Raw SQL | No raw SQL fragments anywhere in the diff |

---

## Detailed Authorization Matrix

### CommentsController

| Action | Auth check | Policy method | Scoping | Verdict |
|---|---|---|---|---|
| create | `before_action :authorize_comment!` | `CommentPolicy#create?` (member + commentable trip) | `@journal_entry.comments.new(user: current_user)` | PASS |
| update | `before_action :authorize_comment!` | `CommentPolicy#update?` (own comment + commentable trip) | `@journal_entry.comments.find(params[:id])` | PASS |
| destroy | `before_action :authorize_comment!` | `CommentPolicy#destroy?` (own comment + commentable trip) | `@journal_entry.comments.find(params[:id])` | PASS |

### ReactionsController

| Action | Auth check | Policy method | Scoping | Verdict |
|---|---|---|---|---|
| create | `before_action :authorize_reaction!` | `ReactionPolicy#create?` (member + commentable trip) | `@journal_entry.reactions.new(user: current_user)` | PASS |
| destroy | `before_action :set_and_authorize_reaction!` | `ReactionPolicy#destroy?` (own reaction + commentable trip) | `@journal_entry.reactions.find(params[:id])` | PASS |

### ChecklistsController

| Action | Auth check | Policy method | Scoping | Verdict |
|---|---|---|---|---|
| index | `before_action :authorize_checklist!` | `ChecklistPolicy#index?` (member) | `@trip.checklists.ordered` | PASS |
| show | `before_action :authorize_checklist!` | `ChecklistPolicy#show?` (member) | `@trip.checklists.find(params[:id])` | PASS |
| new | `before_action :authorize_checklist!` | `ChecklistPolicy#new?` -> `create?` (contributor + writable) | N/A | PASS |
| create | `before_action :authorize_checklist!` | `ChecklistPolicy#create?` (contributor + writable trip) | `@trip.checklists` | PASS |
| edit | `before_action :authorize_checklist!` | `ChecklistPolicy#edit?` (contributor + writable trip) | `@trip.checklists.find(params[:id])` | PASS |
| update | `before_action :authorize_checklist!` | `ChecklistPolicy#update?` (contributor + writable trip) | `@trip.checklists.find(params[:id])` | PASS |
| destroy | `before_action :authorize_checklist!` | `ChecklistPolicy#destroy?` (contributor + writable trip) | `@trip.checklists.find(params[:id])` | PASS |

### ChecklistSectionsController

| Action | Auth check | Policy method | Scoping | Verdict |
|---|---|---|---|---|
| create | `before_action :authorize_checklist!` | `ChecklistPolicy` (contributor + writable trip) | `@checklist.checklist_sections.create!` | PASS |
| destroy | `before_action :authorize_checklist!` | `ChecklistPolicy` (contributor + writable trip) | `@checklist.checklist_sections.find(params[:id])` | PASS |

### ChecklistItemsController

| Action | Auth check | Policy method | Scoping | Verdict |
|---|---|---|---|---|
| create | `before_action :authorize_checklist_item!` | `ChecklistItemPolicy#create?` (contributor + writable trip) | `@checklist.checklist_sections.find(section_id)` | PASS |
| toggle | `before_action :authorize_checklist_item!` | `ChecklistItemPolicy#toggle?` (contributor + writable trip) | Joins through `checklist_sections` scoped to `@checklist.id` | PASS |
| destroy | `before_action :authorize_checklist_item!` | `ChecklistItemPolicy#destroy?` (contributor + writable trip) | Same join scoping as toggle | PASS |

---

## Previously Fixed Issues (for audit trail)

These were identified and fixed during implementation, before this review:

1. **CRITICAL (FIXED in `94317ff`):** `ChecklistItemsController#set_checklist_item` used `ChecklistItem.find(params[:id])` globally, allowing IDOR access to items from any checklist. Fixed by scoping through `checklist_sections` joined to `@checklist.id`.

2. **HIGH (FIXED in `94317ff`):** `ReactionsController#destroy` authorized against a newly built reaction (always owned by `current_user`), not the actual reaction being destroyed. A member could delete other users' reactions. Fixed by splitting into `authorize_reaction!` (create) and `set_and_authorize_reaction!` (destroy).

3. **MEDIUM (FIXED in `94317ff`):** `ChecklistSectionsController` accessed params directly without strong params. Fixed by adding `checklist_section_params` with `params.expect`.

4. **MEDIUM (FIXED in `0df72ba`):** Emoji validation was only at the model level. Commit added explicit `inclusion` validation to the `Reaction` model ensuring only `ALLOWED_EMOJIS` are persisted, with a unique database index enforcing one emoji per user per reactable.

---

## Conclusion

The implementation is secure for merge. The two warnings (W-1 and W-2) are low-risk quality improvements that can be addressed before or after merge at the team's discretion. All five controllers enforce authentication via `require_authenticated_user!` and authorization via ActionPolicy `authorize!` in `before_action` callbacks. Nested resources are properly scoped through their parent records. Strong parameters are enforced on all mutation endpoints (with the minor exception noted in W-1). No new `unsafe_raw` usage was introduced. No secrets or credentials are present in the diff.
