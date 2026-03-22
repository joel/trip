# Phase 5: Security Review

## Issues Found and Resolved

### 1. CRITICAL: ChecklistItem IDOR (FIXED)
**File:** `app/controllers/checklist_items_controller.rb`
**Issue:** `set_checklist_item` used `ChecklistItem.find(params[:id])` globally, allowing access to items from any checklist in the system.
**Fix:** Scoped through checklist sections with `.joins(:checklist_section).where(checklist_sections: { checklist_id: @checklist.id })`.

### 2. HIGH: Reaction Destroy Authorization Gap (FIXED)
**File:** `app/controllers/reactions_controller.rb`
**Issue:** `authorize_reaction!` checked against a newly built reaction (always owned by current user), not the actual reaction being destroyed. A member could delete other users' reactions.
**Fix:** Split into separate `authorize_reaction!` (create) and `set_and_authorize_reaction!` (destroy) that authorizes the actual reaction record.

### 3. MEDIUM: Missing Strong Params (FIXED)
**File:** `app/controllers/checklist_sections_controller.rb`
**Issue:** Accessed `params[:checklist_section][:name]` directly without strong params validation.
**Fix:** Added `checklist_section_params` method using `params.expect()`.

## Areas Reviewed (No Issues Found)

- **CommentsController**: Properly scopes comments through journal_entry, authorizes with correct record
- **ChecklistsController**: Properly scopes checklists through trip, uses strong params
- **All Policies**: Correct membership checks, state guards (commentable?/writable?), own-record validation
- **Models**: No raw SQL, no unsafe string interpolation
- **Routes**: Properly nested, no exposed admin-only endpoints
- **Mass Assignment**: All controllers use strong params or explicit attribute assignment
- **CSRF**: Rails default CSRF protection applies to all form submissions

## Remaining Considerations

- **N+1 queries**: ReactionSummary calls `@entry.reactions.exists?()` per emoji per render. Acceptable for MVP but could be optimized with preloading.
- **Rate limiting**: No rate limiting on comment/reaction creation. Not a security vulnerability but could be abused. Consider adding in a future phase.
