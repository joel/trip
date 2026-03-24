# QA Review -- feature/phase-9-hardening-api-polish

**Branch:** `feature/phase-9-hardening-api-polish`
**Phase:** 9
**Date:** 2026-03-24
**Reviewer:** Claude (adversarial QA pass)

---

## Test Suite Results

- **Full test suite:** 433 examples, 0 failures, 2 pending
- **System tests:** 14 examples, 0 failures
- **Linting:** 365 files inspected, no offenses
- **Brakeman:** 0 warnings
- **bundle-audit:** No vulnerabilities found

---

## Acceptance Criteria

### MCP Endpoint Hardening
- [x] Content-Type validation returns 415 for non-JSON -- PASS (verified: `text/plain` -> 415, missing header -> 415, `application/json; charset=utf-8` -> 200)
- [x] Malformed JSON returns JSON-RPC -32700 parse error -- PASS (verified: `not json{{{` -> `{"error":{"code":-32700,"message":"Parse error"}}`)
- [x] Pagination clamping on `list_journal_entries` -- PASS (verified: `limit:999` clamped to 100, `limit:0` clamped to 1, `offset:-5` clamped to 0)
- [x] Invalid `trip_id` returns "Trip not found" -- PASS (verified: bogus UUID -> `"Trip not found: 00000000-..."`)

### MCP Tool Ergonomics
- [x] `actor_type` validated against allowlist -- PASS (verified: `actor_type: "Evil"` rejected by schema enum)
- [x] `transition_trip` description includes valid transition map -- PASS (description updated, `enum` constraint on `new_state`)
- [x] `add_reaction` emoji constrained by enum -- PASS (verified: `emoji: "clown"` rejected by schema enum)
- [x] Empty updates rejected with error -- PASS (verified: `update_trip` with no params -> `"No updatable parameters provided"`)
- [x] Shared `success_response`/`error_response` helpers in BaseTool -- PASS (all 10 tools refactored)

### Integration Test
- [x] `tools/call` integration test creates journal entry through HTTP -- PASS

### Optimization and Seeds
- [x] `resolve_trip` uses single query (`to_a` + `.size`) -- PASS
- [x] Jack system user in `db/seeds.rb` -- PASS

### Documentation
- [x] MCP_API_KEY scope documented in AGENTS.md -- PASS

### Superadmin State Fix (#21)
- [x] `CommentPolicy` create?/update?/destroy? -- PASS (superadmin blocked on cancelled/archived)
- [x] `ReactionPolicy` create?/destroy? -- PASS (superadmin blocked on cancelled/archived)
- [x] `ChecklistPolicy` create?/edit?/destroy? -- PASS (superadmin blocked on finished/cancelled/archived)
- [x] `ChecklistItemPolicy` create?/toggle?/destroy? -- PASS (superadmin blocked on finished/cancelled/archived)
- [x] Policy specs updated with superadmin-on-locked-trip test cases -- PASS

### Comment Edit UI (#20)
- [x] Edit toggle uses native `<details>` element (no JS dependency) -- PASS
- [x] Edit button guarded by `allowed_to?(:update?, @comment)` -- PASS
- [x] Form uses `form_with(model: [@trip, @entry, @comment])` generating PATCH -- PASS
- [x] System test for inline comment edit flow -- PASS
- [x] Request spec covers PATCH update and Turbo Stream response -- PASS

---

## Defects (must fix before merge)

### D1: JournalEntryPolicy has the same superadmin state bypass bug that was fixed in the other four policies

**File:** `app/policies/journal_entry_policy.rb:9,17,25`

**Steps to reproduce:**
```ruby
admin = User.find_by(email: "joel@acme.org")
finished_trip = Trip.find_by(state: :finished)
entry = finished_trip.journal_entries.first
JournalEntryPolicy.new(entry, user: admin).apply(:create?)  # => true (BUG)
JournalEntryPolicy.new(entry, user: admin).apply(:edit?)     # => true (BUG)
JournalEntryPolicy.new(entry, user: admin).apply(:destroy?)  # => true (BUG)
```

**Expected:** Superadmin should NOT be able to create, edit, or delete journal entries on non-writable trips (finished, cancelled, archived). The state guard must apply to all users including superadmin, exactly as was fixed in CommentPolicy, ReactionPolicy, ChecklistPolicy, and ChecklistItemPolicy.

**Actual:** `JournalEntryPolicy#create?` returns `superadmin? || (contributor? && record.trip.writable?)`. The `superadmin?` short-circuit bypasses the `writable?` check, allowing journal entry creation on finished/cancelled/archived trips.

**Recommended fix:**
```ruby
# Line 9:  change to: (superadmin? || contributor?) && record.trip.writable?
# Line 17: change to: (superadmin? || (contributor? && own_entry?)) && record.trip.writable?
# Line 25: change to: (superadmin? || (contributor? && own_entry?)) && record.trip.writable?
```

Add corresponding spec cases:
```ruby
it "denies superadmin on finished trip" do
  trip.update!(state: :finished)
  expect(described_class.new(entry, user: admin).apply(:create?)).to be(false)
end
```

**Severity:** High -- this is the exact same bug class that GitHub issue #21 was opened for. Phase 9 fixed it in 4 out of 5 affected policies but missed `JournalEntryPolicy`.

---

## Edge Case Gaps (should fix or document)

### E1: MCP UpdateTrip allows updates on writable trips only, but web UI TripPolicy#edit? allows on any state

**Risk if left unfixed:** Inconsistent behavior between the MCP API and the web UI. The MCP `update_trip` tool calls `require_writable!(trip)` which blocks updates on finished/cancelled/archived trips. However, the web `TripsController#update` uses `TripPolicy#edit?` which is `superadmin? || contributor?` with no state check -- allowing name/description edits on any trip state. This is likely intentional (trip metadata should be editable even after finishing) but creates a discrepancy for MCP clients.

**Recommendation:** If trip metadata (name, description) should be editable regardless of state, remove `require_writable!` from `Tools::UpdateTrip` and replace with `resolve_trip` only. If the restriction is intentional for MCP, document the difference. Decide and document.

### E2: Comment edit form has no Cancel button

**Risk if left unfixed:** Users who open the edit form via the `<details>` toggle can close it by clicking the "Edit" summary text again, but there is no explicit "Cancel" button next to "Save". This is a minor UX gap -- the native `<details>` collapse behavior serves as the cancel mechanism, but users unfamiliar with this pattern may not discover it.

**Recommendation:** Consider adding a Cancel button that closes the `<details>` element, or document that clicking "Edit" again collapses the form.

### E3: `find_by!` inside `rescue RecordNotUnique` can raise uncaught RecordNotFound

**Risk if left unfixed:** In `Tools::CreateComment` (line 32-36) and `Tools::CreateJournalEntry` (line 87-91), the `rescue ActiveRecord::RecordNotUnique` handler calls `find_by!` to retrieve the duplicate record. If the record is deleted between the unique constraint violation and the `find_by!` call (extreme race condition), the `RecordNotFound` exception would propagate unhandled because it's outside the `rescue RecordNotFound` block. In practice, this is nearly impossible to trigger.

**Recommendation:** Use `find_by` (without bang) instead of `find_by!` and handle the nil case gracefully, or accept the infinitesimal risk.

### E4: MCP resolve_trip loads all started trips into memory

**Risk if left unfixed:** The optimization changed `Trip.where(state: :started).count` + `.first` (two queries) to `.to_a` + `.size` (one query). While this eliminates a query, it loads all started trips into memory. If a deployment had hundreds of started trips, this could use significant memory. In practice, trip counts are small and this is not a concern.

**Recommendation:** No action needed. Document that this is by design for the expected scale.

---

## Observations

- The Phase 9 changes are well-structured and consistent. The refactoring of all 10 MCP tools to use shared `success_response`/`error_response` helpers significantly reduces code duplication and improves maintainability.

- The `validate_content_type!` filter correctly uses `start_with?("application/json")` to accept charset variations, which is the right approach per RFC 6838.

- The JSON-RPC parse error response correctly returns HTTP 200 with a JSON-RPC error body (code -32700), which follows the JSON-RPC 2.0 specification. Transport-level errors use HTTP status codes (401, 415), while protocol-level errors use JSON-RPC error codes. This is correct.

- The `<details>` element for the comment edit toggle is a good design choice -- it requires no JavaScript and degrades gracefully. The form generates a PATCH request via `form_with(model: ...)` which auto-detects persisted records.

- The seeds file correctly adds the Jack user with `roles: []` (no app roles) and `status: 2` (verified). The `find_or_create_by!` in `BaseTool` remains as a production safety net.

- The `VALID_ACTOR_TYPES` constant in `BaseTool` is redundant with the `enum` constraint in the `CreateJournalEntry` input schema. The MCP gem validates the enum at the schema level before `call` is invoked, so `validate_actor_type!` would never actually fire for schema-constrained tools. However, the dual validation is defense-in-depth and harmless.

- Policy specs are thorough. Each policy has tests for superadmin on commentable/writable trips AND superadmin on locked trips. The test naming was updated from "allows superadmin" to "allows superadmin on writable/commentable trip" which improves clarity.

---

## Regression Check

- **Trip CRUD** -- PASS (pages return 200, seed trips accessible)
- **Journal entries** -- PASS (entries render with comments and reactions)
- **Authentication** -- PASS (login page renders, email auth endpoints respond correctly)
- **Comments & reactions** -- PASS (seeded comments render, edit/delete authorization logic verified via policy checks)
- **Checklists** -- PASS (seeded checklists accessible via MCP tools)
- **MCP endpoint** -- PASS (initialize, tools/list, tools/call all functional)

---

## Summary

Phase 9 successfully addresses the review findings from Phase 8 with one significant omission: **JournalEntryPolicy was not included in the superadmin state bypass fix** (D1). This is the same bug class as GitHub issue #21, which Phase 9 intended to close. The fix was applied to CommentPolicy, ReactionPolicy, ChecklistPolicy, and ChecklistItemPolicy, but JournalEntryPolicy retains the original `superadmin? || (condition && state_check)` pattern that allows superadmin to create, edit, and delete journal entries on non-writable trips.

D1 must be fixed before merge. The edge case gaps (E1-E4) are low-severity and can be deferred or documented.
