# Security Review -- feature/phase-8-mcp-server-integration

**Date:** 2026-03-24
**Reviewer:** Claude (adversarial security pass)
**Scope:** All files in `git diff main...HEAD` (32 files)

---

## Critical (must fix before merge)

No critical findings.

---

## Warning (should fix or consciously accept)

### W-1: No upper bound on `limit` parameter in `ListJournalEntries`

**File:** `app/mcp/tools/list_journal_entries.rb:15`

The `limit` parameter defaults to 10 but has no maximum. A caller can pass `limit: 1000000` and force the server to load and serialize an unbounded number of records into memory. Similarly, `offset` has no floor (a negative value would be passed to SQL, where behavior is database-dependent).

**Recommendation:** Clamp `limit` to a reasonable ceiling (e.g., 100) and ensure `offset` is non-negative:

```ruby
limit = [[limit.to_i, 1].max, 100].min
offset = [offset.to_i, 0].max
```

---

### W-2: No rate limiting on the `/mcp` endpoint

**File:** `app/controllers/mcp_controller.rb`

The `/mcp` endpoint has no rate limiting. A compromised or misconfigured MCP client can flood the server with requests. The rest of the application also lacks `Rack::Attack` or similar middleware, so this is not a regression, but this endpoint is API-facing (no CSRF, no session) which makes it a higher-value target.

**Recommendation:** Add rate limiting via `Rack::Attack` or a `before_action` throttle scoped to the API key. This can be deferred to a hardening phase if the endpoint is only reachable from a trusted network.

---

### W-3: `actor_type` and `actor_id` are caller-controlled free-text strings

**File:** `app/mcp/tools/create_journal_entry.rb:15-16`

The `actor_type` and `actor_id` fields are stored verbatim from the MCP request. An attacker with a valid API key could set `actor_type` to any string (e.g., impersonate a human user's name). There is no validation on the model either.

**Recommendation:** If actor attribution is intended only for system actors, validate `actor_type` against an allowlist (e.g., `%w[Jack System]`). If flexibility is intentional, accept the risk but add a model-level length validation to prevent storage abuse.

---

### W-4: `resolve_jack_user` creates a verified user account as a side effect

**File:** `app/mcp/tools/base_tool.rb:24-29`

`find_or_create_by!` with `status: 2` creates a fully verified Rodauth account on first MCP request. If the user record is later deleted (e.g., by an admin), the next MCP request silently recreates it. The email `jack@system.local` has no domain validation, so it will pass the uniqueness check but could conflict with real users if the email validation rules change.

This is an acceptable design decision (documented in Phase 8 plan), but note:
- The Jack user has no `roles_mask` set explicitly. It inherits the default (`guest` role via `Roleable`). Confirm this is the intended permission level for the system user.
- The `name` attribute has no presence validation on the `User` model, but this is set correctly here.

**Recommendation:** Consider seeding the Jack user in `db/seeds.rb` instead of lazy-creating in production, to avoid the first-request side effect. If lazy creation is preferred, add a comment explaining why `status: 2` is safe.

---

### W-5: `UpdateJournalEntry` error message leaks the UUID back to the caller

**File:** `app/mcp/tools/update_journal_entry.rb:28`

```ruby
error_response("Journal entry not found: #{journal_entry_id}")
```

This echoes the caller-supplied UUID back in the error message. While not a data leak (the caller already knows the UUID they sent), this pattern can enable reflected content injection if error messages are ever rendered in HTML. The same pattern appears in `CreateComment` (line 44), `AddReaction` (line 22), and `ToggleChecklistItem` (line 33).

Since all MCP responses are JSON and consumed by an AI client (not rendered in a browser), this is low risk. The MCP controller inherits from `ActionController::API` which does not render HTML.

**Recommendation:** Acceptable for an API-only endpoint. No action required unless error messages are ever surfaced in a web UI.

---

### W-6: Unscoped `find` calls without ActionPolicy authorization

**Files:**
- `app/mcp/tools/update_journal_entry.rb:23` -- `JournalEntry.find(journal_entry_id)`
- `app/mcp/tools/create_comment.rb:18` -- `JournalEntry.find(journal_entry_id)`
- `app/mcp/tools/add_reaction.rb:16` -- `JournalEntry.find(journal_entry_id)`
- `app/mcp/tools/toggle_checklist_item.rb:15` -- `ChecklistItem.find(checklist_item_id)`
- `app/mcp/tools/base_tool.rb:9` -- `Trip.find(trip_id)`

The MCP tools perform unscoped `find` calls without any ActionPolicy `authorize!` checks. This means the MCP endpoint (with a valid API key) can read/write any record in the database regardless of trip membership or ownership.

Per the project's SKILL.md: "Do NOT flag unscoped `find` as a vulnerability unless the controller is also missing `authorize!`." The `McpController` has no `authorize!` -- it uses API key auth instead.

This is an **intentional design decision** (Jack is a superuser system actor), but it should be consciously accepted:
- Anyone with the `MCP_API_KEY` has full read/write access to ALL trips, journal entries, comments, checklists, and reactions.
- The API key is a single shared secret with no per-user scoping.

**Recommendation:** Document in the Phase 8 docs that the MCP API key grants unrestricted access to all domain data. If multi-tenant isolation is needed in the future, add trip-scoped authorization to MCP tools.

---

## Informational (no action required)

### I-1: Authentication implementation is solid

The `authenticate_api_key!` method in `McpController` correctly:
- Returns 401 when `MCP_API_KEY` is blank/unset (prevents accidental open access)
- Uses `ActiveSupport::SecurityUtils.secure_compare` (prevents timing attacks)
- Extracts the token from the `Authorization: Bearer <token>` header (standard pattern)
- Calls `head(:unauthorized)` which returns no body (no information leakage)

### I-2: CSRF protection is correctly absent

`McpController` inherits from `ActionController::API` (not `ApplicationController`), which excludes CSRF middleware. This is correct for a Bearer-token API endpoint.

### I-3: Idempotency implementation is correct

- Unique partial indexes on `[trip_id, telegram_message_id]` and `[journal_entry_id, telegram_message_id]` with `WHERE telegram_message_id IS NOT NULL` correctly scope idempotency per parent resource.
- Both `CreateJournalEntry` and `CreateComment` handle the `ActiveRecord::RecordNotUnique` race condition by rescuing and returning the existing record.
- The `find_by` check before creation provides a fast path; the unique index rescue handles the race condition.

### I-4: Input validation is delegated to the Action layer and model validations

MCP tools do not use Rails strong parameters (they receive keyword arguments from the MCP gem's JSON schema validation). Input flows through:
1. MCP gem JSON schema validation (type checking)
2. Service object (Action) layer
3. ActiveRecord model validations

This is acceptable because the MCP gem validates types against the declared `input_schema`, and the Action layer performs business validation.

### I-5: No `unsafe_raw`, `html_safe`, or `raw` usage

No Phlex-unsafe output methods are used in the MCP code. All responses are JSON strings via `.to_json`.

### I-6: New gem dependency

The `mcp` gem (0.8.0) has been added. It is a pre-1.0 gem with a dependency on `json-schema`. The gem is already used transitively in the Gemfile.lock. No known CVEs at time of review.

### I-7: `request.body.read` is safe here

`McpController#handle` calls `request.body.read` directly. This is safe because:
- `ActionController::API` does not parse the body for API requests when Content-Type is application/json (Rails parses it, but the raw body is still available)
- The MCP gem handles its own JSON parsing
- There is no double-read concern since the controller does not access `params` for the body

### I-8: No secrets in the diff

No `.env` files, credentials, or hardcoded secrets are present in the diff. The `MCP_API_KEY` is read from an environment variable at runtime.

---

## Not applicable

| Category | Reason |
|----------|--------|
| **File uploads** | No file upload functionality in MCP tools |
| **Invitation/token flows** | No token-based flows introduced |
| **Nested resource scoping** | Tools use unscoped `find` by design (see W-6) |
| **Output escaping (HTML)** | All output is JSON; no HTML rendering |
| **CSRF** | API endpoint uses Bearer token auth (see I-2) |

---

## Summary

The MCP server implementation is well-structured with solid authentication, correct idempotency handling, and clean delegation to existing Action objects. The primary concerns are:

1. **W-1 (unbounded pagination)** -- easy fix, recommended before merge
2. **W-2 (no rate limiting)** -- acceptable to defer if the endpoint is network-restricted
3. **W-3 (free-text actor fields)** -- low risk, but an allowlist is cheap insurance
4. **W-4 (lazy user creation)** -- acceptable design, but seed-based creation is safer
5. **W-6 (unrestricted data access via API key)** -- intentional, but should be documented

No critical vulnerabilities were found. The authentication gate is correctly implemented and the existing Action layer provides proper validation for all mutations.
