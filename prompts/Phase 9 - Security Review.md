# Security Review -- feature/phase-9-hardening-api-polish

**Date:** 2026-03-24
**Reviewer:** Claude (adversarial security pass)
**Scope:** `git diff main...HEAD` (3 commits, 27 files, +679/-213 lines)

---

## Summary

Phase 9 is a hardening and polish phase. The changes include: MCP endpoint input validation (Content-Type check, JSON parse validation), MCP tool ergonomics (shared helpers, input schema enums, pagination clamping), a superadmin policy bypass fix across 4 policies, and a new inline comment edit UI. Overall, this phase materially improves the security posture. One remaining vulnerability was identified in a policy that was not included in the fix batch.

---

## Critical (must fix before merge)

### 1. JournalEntryPolicy still has the superadmin state bypass

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/policies/journal_entry_policy.rb` lines 9, 17, 25

The same operator-precedence bug that was fixed in `CommentPolicy`, `ReactionPolicy`, `ChecklistPolicy`, and `ChecklistItemPolicy` still exists in `JournalEntryPolicy`. A superadmin can create, edit, update, and destroy journal entries on non-writable trips (finished, cancelled, archived).

**Current code:**
```ruby
def create?
  superadmin? || (contributor? && record.trip.writable?)
end

def edit?
  superadmin? || (contributor? && own_entry? && record.trip.writable?)
end

def destroy?
  superadmin? || (contributor? && own_entry? && record.trip.writable?)
end
```

**Fix:** Apply the same parenthesization pattern used in the other 4 policies:
```ruby
def create?
  (superadmin? || contributor?) && record.trip.writable?
end

def edit?
  (superadmin? || (contributor? && own_entry?)) && record.trip.writable?
end

def destroy?
  (superadmin? || (contributor? && own_entry?)) && record.trip.writable?
end
```

This is the exact same class of bug that GitHub issue #21 describes. Not fixing it here leaves the most important resource (journal entries) unprotected while fixing less critical ones (checklists, comments, reactions).

---

## Warning (should fix or consciously accept)

### 2. Jack system user auto-created without role restrictions

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/mcp/tools/base_tool.rb:52`

`resolve_jack_user` uses `find_or_create_by!` which will create the Jack user on first MCP request if it does not exist. The user is created with `status: 2` (Rodauth verified) and no roles. This is acceptable for the current design (Jack is the AI actor), but note:

- If someone gains access to the MCP API key, they can trigger user creation in production.
- The Jack user has no roles, so it cannot bypass policies through the web UI. This is correct.

**Recommendation:** Consider seeding the Jack user in production migrations rather than relying on auto-creation. The seeds file already creates it, but seeds are not always run in production. Consciously accept or add a migration.

### 3. No rate limiting on the MCP endpoint

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/controllers/mcp_controller.rb`

The `/mcp` endpoint has authentication (API key) but no rate limiting. A compromised or leaked API key would allow unlimited requests. This was noted in previous security reviews and remains outstanding.

**Recommendation:** Add Rack::Attack or a similar throttle for the `/mcp` route. Defer to a follow-up issue if not in scope.

### 4. MCP request body is parsed twice

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/controllers/mcp_controller.rb:8-13`

The request body is read once, parsed by `JSON.parse(body)` for validation, then passed to `server.handle_json(body)` which parses it again internally. This is functionally correct but wastes CPU. More importantly, if a very large JSON payload is sent, it will be parsed twice, consuming memory.

**Recommendation:** Consider passing the already-parsed object to the MCP server if the API supports it, or accept the double-parse as a minor cost. Not a security vulnerability per se, but could contribute to denial-of-service under load (compounded by the lack of rate limiting).

### 5. ExportPolicy has inconsistent superadmin state check

**File:** `/home/joel/Workspace/Workanywhere/catalyst/app/policies/export_policy.rb:9`

`ExportPolicy#create?` was already fixed to use the correct pattern `(superadmin? || member?) && trip.commentable?`, but `ExportPolicy#show?` on line 17 uses `superadmin? || (member? && own_export?)`. This is a different case (read-only, no state check) so it may be intentional -- a superadmin should probably be able to view any export regardless of trip state. Flag for conscious acceptance.

---

## Informational (no action required)

### 6. Policy fix is correct and well-tested

The superadmin state bypass fix in `CommentPolicy`, `ReactionPolicy`, `ChecklistPolicy`, and `ChecklistItemPolicy` is correctly implemented. The operator precedence change from `superadmin? || (X && state_check)` to `(superadmin? || X) && state_check` correctly enforces that the state guard applies to everyone, including superadmins. All four policies have new spec coverage for superadmin-on-non-writable/non-commentable trips.

### 7. MCP input validation improvements are sound

- Content-Type validation (`validate_content_type!`) correctly rejects non-JSON requests with 415.
- JSON parse validation catches malformed payloads before they reach the MCP server.
- Pagination clamping (`limit.to_i.clamp(1, 100)` and `[offset.to_i, 0].max`) prevents unbounded queries.
- `enum` constraints on `actor_type`, `new_state`, and `emoji` in input schemas provide schema-level validation.
- `validate_actor_type!` provides server-side enforcement beyond schema validation.
- Empty params check on `update_trip` and `update_journal_entry` prevents no-op mutations.

### 8. Comment edit UI authorization is correctly gated

The `can_edit?` method in `CommentCard` checks `allowed_to?(:update?, @comment)` which delegates to `CommentPolicy#update?`. The controller's `authorize_comment!` before_action enforces this server-side. The `form_with(model: [@trip, @entry, @comment])` generates a PATCH to the existing `update` route. Strong parameters (`params.expect(comment: [:body])`) are enforced.

### 9. No new `unsafe_raw` or `html_safe` usage

The diff introduces no new unsafe output methods. The existing `raw safe(...)` calls in Rodauth forms are pre-existing and not part of this diff.

### 10. No new gems or dependencies added

The Gemfile and Gemfile.lock are unchanged in this branch.

### 11. No secrets or credentials in the diff

No hardcoded API keys, tokens, or passwords are present. The MCP API key is read from an environment variable.

### 12. Shared response helpers reduce code duplication

The extraction of `success_response` and `error_response` into `BaseTool` eliminates 10 per-tool copies of the same logic, reducing the surface area for response-format bugs.

---

## Checklist

| Category | Status |
|---|---|
| Authentication & Authorization | FINDING #1 (JournalEntryPolicy bypass) |
| Input & Output | Pass -- improved by this phase |
| Data Exposure | Pass -- error messages are generic |
| Mass Assignment & Query Safety | Pass -- strong params enforced |
| Secrets & Configuration | Pass -- no secrets committed |
| Dependencies | Pass -- no new deps |

---

## Verdict

**One critical finding must be fixed before merge:** the `JournalEntryPolicy` superadmin state bypass (finding #1). This is the same class of bug fixed in 4 other policies in this very branch, and leaving the most important resource (journal entries) unfixed would be inconsistent and exploitable.

Warnings #2-#5 should be triaged: accept consciously or defer to follow-up issues.
