# Phase 9: Hardening & API Polish - Steps Taken

## Date: 2026-03-24

## GitHub Issue: #37
## PR: #38
## Branch: feature/phase-9-hardening-api-polish

---

## Steps

### 1. Setup
- Created GitHub issue #37 with detailed scope
- Created branch `feature/phase-9-hardening-api-polish` from `main`
- Note: Kanban board requires interactive auth refresh for project scope

### 2. MCP Endpoint Hardening (Scope 1a-1d)
- **McpController:** Added `validate_content_type!` before_action returning 415 for non-JSON
- **McpController:** Added `JSON.parse` pre-validation with `rescue JSON::ParserError` returning JSON-RPC `-32700`
- **BaseTool#resolve_trip:** Added `rescue ActiveRecord::RecordNotFound` with friendly "Trip not found: {id}" message
- **ListJournalEntries:** Clamped `limit` to `[1..100]` and `offset` to `[0..]`

### 3. MCP Tool Ergonomics (Scope 2a-2e)
- **BaseTool:** Added shared `success_response(data)` and `error_response(errors)` class methods
- **BaseTool:** Added `VALID_ACTOR_TYPES = %w[Jack System]` and `validate_actor_type!` helper
- **CreateJournalEntry:** Added `validate_actor_type!` call and `enum` constraint in input_schema
- **TransitionTrip:** Updated description with valid transition map, added `enum` constraint to `new_state`
- **AddReaction:** Added `enum: Reaction::ALLOWED_EMOJIS` constraint to `emoji` in input_schema
- **UpdateTrip, UpdateJournalEntry:** Added empty params check raising ToolError
- **All 10 tools:** Refactored to use shared `success_response`/`error_response` from BaseTool, removed per-tool duplicates

### 4. Integration Test + Optimization + Seeds + Docs (Scope 3-6)
- **mcp_spec.rb:** Added `tools/call` integration test that creates a journal entry through HTTP
- **mcp_spec.rb:** Added Content-Type validation test (415) and malformed JSON test (-32700)
- **BaseTool#resolve_trip:** Replaced `count` + `first` with `.to_a` + `.size` (single query)
- **db/seeds.rb:** Added Jack system user (`jack@system.local`, status: 2)
- **CLAUDE.md:** Documented MCP_API_KEY scope and Jack actor

### 5. Superadmin Trip State Bypass Fix (GitHub #21)
- **CommentPolicy:** Changed `superadmin? || (condition && state_check)` to `(superadmin? || condition) && state_check` for create?/update?/destroy?
- **ReactionPolicy:** Same pattern fix for create?/destroy?
- **ChecklistPolicy:** Same pattern fix for create?/edit?/destroy?
- **ChecklistItemPolicy:** Same pattern fix for create?/toggle?/destroy?
- **Policy specs:** Added superadmin-on-cancelled/archived/finished test cases for all 4 policies

### 6. Comment Edit UI (GitHub #20)
- **CommentCard:** Added `<details>` toggle with `<summary>Edit</summary>` and inline edit form (textarea + Save)
- **CommentCard:** Added `can_edit?` method using `allowed_to?(:update?, @comment)`
- **comments_spec.rb:** New system test verifying inline edit flow
- Removed Stimulus controller approach in favor of native HTML `<details>` (no JS dependency)

### 7. Validation & Push
- `bundle exec rake project:fix-lint` - clean
- `bundle exec rake project:lint` - 365 files, no offenses
- `bundle exec rake project:tests` - 433 examples, 0 failures
- `bundle exec rake project:system-tests` - 14 examples, 0 failures
- `bundle exec brakeman -q` - 0 warnings
- `bundle exec bundle-audit check` - no vulnerabilities
- Pushed to `origin/feature/phase-9-hardening-api-polish`
- Created PR #38 closing #20, #21, #37

## Files Modified (25)
| File | Changes |
|------|---------|
| `AGENTS.md` | MCP_API_KEY scope documentation |
| `app/components/comment_card.rb` | Edit button + inline edit form |
| `app/controllers/mcp_controller.rb` | Content-Type check, JSON parse rescue |
| `app/mcp/tools/base_tool.rb` | Shared helpers, RecordNotFound, optimize query, actor_type |
| `app/mcp/tools/add_reaction.rb` | Shared helpers, emoji enum |
| `app/mcp/tools/create_comment.rb` | Shared helpers, refactored extraction |
| `app/mcp/tools/create_journal_entry.rb` | Shared helpers, actor_type validation |
| `app/mcp/tools/get_trip_status.rb` | Shared helpers |
| `app/mcp/tools/list_checklists.rb` | Shared helpers |
| `app/mcp/tools/list_journal_entries.rb` | Shared helpers, pagination clamping |
| `app/mcp/tools/toggle_checklist_item.rb` | Shared helpers |
| `app/mcp/tools/transition_trip.rb` | Shared helpers, description + enum |
| `app/mcp/tools/update_journal_entry.rb` | Shared helpers, reject empty |
| `app/mcp/tools/update_trip.rb` | Shared helpers, reject empty |
| `app/policies/checklist_item_policy.rb` | Superadmin state fix |
| `app/policies/checklist_policy.rb` | Superadmin state fix |
| `app/policies/comment_policy.rb` | Superadmin state fix |
| `app/policies/reaction_policy.rb` | Superadmin state fix |
| `db/seeds.rb` | Jack system user |
| `spec/policies/checklist_item_policy_spec.rb` | Superadmin state tests |
| `spec/policies/checklist_policy_spec.rb` | Superadmin state tests |
| `spec/policies/comment_policy_spec.rb` | Superadmin state tests |
| `spec/policies/reaction_policy_spec.rb` | Superadmin state tests |
| `spec/requests/mcp_spec.rb` | Integration test, Content-Type, parse error |
| `spec/system/comments_spec.rb` | Comment edit system test (NEW) |
