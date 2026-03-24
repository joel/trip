# Phase 9: Hardening & API Polish

## Context

Phases 1-8 are complete. The application has full trip journaling, comments, reactions, checklists, exports, event-driven workflows, PWA support, and an MCP server with 10 tools. The codebase has 428 specs passing, comprehensive seed data, Brakeman and bundle-audit clean, and a deployed production instance.

The Phase 8 reviews (QA, Security, UX) surfaced actionable warnings, friction items, and edge cases that should be addressed before the codebase is considered V1-complete. This phase consolidates that debt into a single hardening pass.

Additionally, two open GitHub issues (#20, #21) from earlier phases remain unresolved and fit naturally into a hardening pass.

**Goal:** Address all review findings from Phase 8, fix open GitHub issues, harden the MCP endpoint, improve API ergonomics, and close remaining quality gaps to achieve V1 production readiness.

**Issue:** To be created on GitHub (joel/trip)

---

## Scope

### 1. MCP Endpoint Hardening

#### 1a. Clamp pagination parameters (Security W-1)
- **File:** `app/mcp/tools/list_journal_entries.rb`
- Clamp `limit` to `[1..100]` and `offset` to `[0..]`
- Prevents unbounded memory allocation from `limit: 1000000`

#### 1b. Content-Type validation (UX F1)
- **File:** `app/controllers/mcp_controller.rb`
- Add `before_action` that returns 415 Unsupported Media Type if `Content-Type` is not `application/json`

#### 1c. Malformed JSON rescue (UX F2)
- **File:** `app/controllers/mcp_controller.rb`
- Rescue `JSON::ParserError` (or whatever the MCP gem raises) and return a proper JSON-RPC `-32700` parse error response

#### 1d. RecordNotFound in resolve_trip (QA E1)
- **File:** `app/mcp/tools/base_tool.rb`
- Add `rescue ActiveRecord::RecordNotFound` to `resolve_trip` and raise `ToolError` with a friendly "Trip not found: {id}" message instead of the generic "Internal error" wrapper

### 2. MCP Tool Ergonomics

#### 2a. Validate actor_type against allowlist (Security W-3)
- **File:** `app/mcp/tools/create_journal_entry.rb`
- Validate `actor_type` against `%w[Jack System]` before persisting
- Return error if caller sends an unrecognized actor_type

#### 2b. Document valid transitions in TransitionTrip (UX F4)
- **File:** `app/mcp/tools/transition_trip.rb`
- Update the tool `description` to include the valid transition map
- Add `enum` constraint to `new_state` in `input_schema`: `%w[planning started finished cancelled archived]`

#### 2c. Add enum constraint to AddReaction emoji (UX S5)
- **File:** `app/mcp/tools/add_reaction.rb`
- Add `enum` to `emoji` in `input_schema` matching `Reaction::ALLOWED_EMOJIS`

#### 2d. Reject empty updates (QA E3, UX F5)
- **Files:** `app/mcp/tools/update_trip.rb`, `app/mcp/tools/update_journal_entry.rb`
- Return an error when no updatable params are provided instead of silently no-opping

#### 2e. Consolidate error/success response helpers (QA E4, UX F6)
- **File:** `app/mcp/tools/base_tool.rb` + all tools
- Extract shared `success_response(data)` and `error_response(message_or_errors)` methods into `BaseTool`
- Refactor all 10 tools to use the shared helpers instead of per-tool variants

### 3. MCP Integration Test (QA E7)

#### 3a. Add tools/call integration test
- **File:** `spec/requests/mcp_spec.rb`
- Add at least one test that calls a tool through `POST /mcp` with `tools/call` JSON-RPC and verifies the database side effect (e.g., `create_journal_entry` creates a record)

### 4. Optimize resolve_trip query (UX F8)
- **File:** `app/mcp/tools/base_tool.rb`
- Replace the two-query `count` + `first` pattern with a single `to_a` + `.size` check

### 5. Seed Jack user (Security W-4)
- **File:** `db/seeds.rb`
- Add the Jack system user (`jack@system.local`, status: 2, name: "Jack") to seeds
- Keep `find_or_create_by!` in `BaseTool` as a safety net, but prefer seeded creation

### 6. Document MCP_API_KEY scope (Security W-6)
- **File:** `CLAUDE.md` or `README.md`
- Add a section documenting that the MCP API key grants unrestricted read/write access to all domain data
- Note that this is intentional for the Jack system actor

### 7. Fix: Superadmin should respect trip state constraints (GitHub #21)
- **Files:** `app/policies/comment_policy.rb`, `app/policies/reaction_policy.rb`, `app/policies/checklist_policy.rb`, `app/policies/checklist_item_policy.rb`
- **Bug:** Superadmin bypasses `writable?`/`commentable?` checks in all four policies. The `superadmin?` short-circuit in `create?`/`update?`/`destroy?` allows writes on cancelled/archived trips.
- **Fix:** Change pattern from `superadmin? || (member? && trip.commentable?)` to `(superadmin? || member?) && trip.commentable?` for write actions. Read actions (`show?`/`index?`) remain unrestricted.
- Update corresponding policy specs to verify superadmin is blocked on archived/cancelled trips
- Closes #21

### 8. Feature: Add comment edit UI to CommentCard (GitHub #20)
- **Files:** `app/components/comment_card.rb`, possibly a new `CommentEditForm` component or inline Turbo Frame
- **Gap:** Backend supports comment editing (`CommentsController#update`, `Comments::Update` action, `CommentPolicy#update?`) but the UI only shows a Delete button. Users cannot edit their comments.
- **Fix:** Add an "Edit" button to `CommentCard` guarded by `allowed_to?(:update?, @comment)`. On click, reveal an inline edit form (textarea + Save/Cancel) via Turbo Frame or Stimulus toggle. On save, submit `PATCH` to `CommentsController#update`.
- Add system test for comment edit flow
- Closes #20

---

## Files to Modify (~18)

| File | Changes |
|------|---------|
| `app/controllers/mcp_controller.rb` | Content-Type check, JSON parse rescue |
| `app/mcp/tools/base_tool.rb` | Shared response helpers, RecordNotFound rescue in resolve_trip, optimize query, actor_type validation helper |
| `app/mcp/tools/list_journal_entries.rb` | Clamp limit/offset |
| `app/mcp/tools/create_journal_entry.rb` | Use shared helpers, actor_type validation |
| `app/mcp/tools/update_journal_entry.rb` | Use shared helpers, reject empty updates |
| `app/mcp/tools/create_comment.rb` | Use shared helpers |
| `app/mcp/tools/add_reaction.rb` | Use shared helpers, enum constraint on emoji |
| `app/mcp/tools/update_trip.rb` | Use shared helpers, reject empty updates |
| `app/mcp/tools/transition_trip.rb` | Use shared helpers, updated description + enum |
| `app/mcp/tools/toggle_checklist_item.rb` | Use shared helpers |
| `app/mcp/tools/list_checklists.rb` | Use shared helpers |
| `app/mcp/tools/get_trip_status.rb` | Use shared helpers |
| `spec/requests/mcp_spec.rb` | Integration test for tools/call |
| `db/seeds.rb` | Add Jack system user |
| `app/policies/comment_policy.rb` | Fix superadmin state bypass (#21) |
| `app/policies/reaction_policy.rb` | Fix superadmin state bypass (#21) |
| `app/policies/checklist_policy.rb` | Fix superadmin state bypass (#21) |
| `app/policies/checklist_item_policy.rb` | Fix superadmin state bypass (#21) |
| `app/components/comment_card.rb` | Add Edit button + inline edit form (#20) |

| File | Changes |
|------|---------|
| `app/controllers/mcp_controller.rb` | Content-Type check, JSON parse rescue |
| `app/mcp/tools/base_tool.rb` | Shared response helpers, RecordNotFound rescue in resolve_trip, optimize query, actor_type validation helper |
| `app/mcp/tools/list_journal_entries.rb` | Clamp limit/offset |
| `app/mcp/tools/create_journal_entry.rb` | Use shared helpers, actor_type validation |
| `app/mcp/tools/update_journal_entry.rb` | Use shared helpers, reject empty updates |
| `app/mcp/tools/create_comment.rb` | Use shared helpers |
| `app/mcp/tools/add_reaction.rb` | Use shared helpers, enum constraint on emoji |
| `app/mcp/tools/update_trip.rb` | Use shared helpers, reject empty updates |
| `app/mcp/tools/transition_trip.rb` | Use shared helpers, updated description + enum |
| `app/mcp/tools/toggle_checklist_item.rb` | Use shared helpers |
| `app/mcp/tools/list_checklists.rb` | Use shared helpers |
| `app/mcp/tools/get_trip_status.rb` | Use shared helpers |
| `spec/requests/mcp_spec.rb` | Integration test for tools/call |
| `db/seeds.rb` | Add Jack system user |

## Files to Create (~0)

No new files expected. All changes are modifications to existing files.

---

## Key Design Decisions

1. **Shared response helpers in BaseTool** — All 10 tools will use `success_response(data_hash)` and `error_response(message_or_errors)` from `BaseTool`. This eliminates the current inconsistency where each tool defines its own variant (`tool_response`, `success_response`, `text_response`, `text_error`, inline `MCP::Tool::Response.new`).

2. **Actor type allowlist** — Validate `actor_type` against a fixed list rather than accepting arbitrary strings. Default remains "Jack". This is cheap insurance against misuse with a valid API key.

3. **JSON-RPC error codes** — Use standard JSON-RPC error codes for transport-level errors: `-32700` for parse errors, `-32600` for invalid requests. Tool-level errors remain in the MCP `isError` response body.

4. **Seeded Jack user** — The Jack user should exist in seeds for development and be created during deployment. The `find_or_create_by!` in `BaseTool` remains as a safety net but is not the primary creation path.

---

## Risks

1. **Response helper refactoring scope** — Changing all 10 tools to use shared helpers is straightforward but touches many files. Risk of introducing regressions in edge cases. Mitigate with existing 39 MCP specs.

2. **Content-Type validation may break non-standard clients** — Some MCP clients might not set `Content-Type: application/json`. Mitigate by only requiring the header starts with `application/json` (allowing `application/json; charset=utf-8`).

3. **Enum constraint on new_state** — Adding `enum` to the JSON schema may cause the MCP gem to reject invalid values before the tool runs. Verify the gem's schema validation behavior.

---

## Verification

### Automated Tests
```bash
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
mise x -- bundle exec rake project:lint
mise x -- bundle exec brakeman -q
mise x -- bundle exec bundle-audit check
```

### Runtime Verification
- [ ] `POST /mcp` with `Content-Type: text/plain` returns 415
- [ ] `POST /mcp` with invalid JSON returns JSON-RPC `-32700` error
- [ ] `list_journal_entries` with `limit: 999999` clamps to 100
- [ ] `create_journal_entry` with `actor_type: "hacker"` returns error
- [ ] `transition_trip` with `new_state: "flying"` is rejected by schema
- [ ] `update_trip` with no params returns error
- [ ] Invalid `trip_id` returns "Trip not found" (not "Internal error")
- [ ] Superadmin cannot create comment on archived trip (web UI)
- [ ] Comment edit button visible to author, inline form works
- [ ] All existing tests still pass
- [ ] No Bullet N+1 alerts

### Definition of Done
- [ ] All Phase 8 review warnings (W-1 through W-4, W-6) addressed
- [ ] All Phase 8 UX friction items (F1, F2, F4, F5, F6) addressed
- [ ] All Phase 8 QA edge cases (E1, E3, E4, E7) addressed
- [ ] Consistent error/success response pattern across all 10 tools
- [ ] Integration test for tools/call through HTTP
- [ ] Jack user in seeds
- [ ] MCP_API_KEY scope documented
- [ ] Superadmin respects trip state constraints in all policies (Closes #21)
- [ ] Comment edit UI functional with inline form (Closes #20)
- [ ] No regressions in existing 428+ specs
- [ ] Brakeman + bundle-audit clean
- [ ] Zero open GitHub issues
