# UI Designer Review -- Phase 8: MCP Server Integration

Branch: `feature/phase-8-mcp-server-integration`

## Files Reviewed

### Phase 8 changes (all new files, API-only)

- `app/mcp/trip_journal_server.rb`
- `app/mcp/tools/base_tool.rb`
- `app/mcp/tools/create_journal_entry.rb`
- `app/mcp/tools/update_journal_entry.rb`
- `app/mcp/tools/list_journal_entries.rb`
- `app/mcp/tools/create_comment.rb`
- `app/mcp/tools/add_reaction.rb`
- `app/mcp/tools/update_trip.rb`
- `app/mcp/tools/transition_trip.rb`
- `app/mcp/tools/toggle_checklist_item.rb`
- `app/mcp/tools/list_checklists.rb`
- `app/mcp/tools/get_trip_status.rb`
- `app/controllers/mcp_controller.rb`
- `config/routes.rb` (one line added: `post "/mcp"`)
- `db/schema.rb` (new columns: `actor_type`, `actor_id`, `telegram_message_id`)

### Existing UI files checked for impact

- All 33 Phlex components in `app/components/`
- All 40 Phlex views in `app/views/`
- `app/assets/tailwind/application.css`
- All 4 Stimulus controllers in `app/javascript/controllers/`
- All 7 `ui_library/*.yml` entries

---

## Phase 8 UI Impact Assessment: None

Phase 8 is a purely API-only change. The entire scope is:

1. A new `POST /mcp` JSON-RPC endpoint served by `McpController < ActionController::API`
2. 10 MCP tool classes under `app/mcp/tools/` that return `MCP::Tool::Response` objects containing JSON text
3. Three new database columns (`actor_type`, `actor_id` on `journal_entries`; `telegram_message_id` on `journal_entries` and `comments`)

**No Phlex components were created, modified, or deleted.** No views were changed. No Stimulus controllers were added or updated. No CSS was modified. No Tailwind classes were introduced. No design tokens were added or changed.

The diff between `main` and `HEAD` confirms this: all 31 changed files are either backend Ruby (controllers, MCP tools, models, migrations, specs) or infrastructure (Gemfile, routes, schema). Zero files under `app/components/`, `app/views/`, `app/assets/`, or `app/javascript/` appear in the diff.

---

## New Data Fields -- Future UI Considerations

Phase 8 adds three columns that are visible in MCP tool JSON responses but are **not yet surfaced in any Phlex component or view**:

### 1. `journal_entries.actor_type` and `journal_entries.actor_id`

These fields track whether a journal entry was created by a human user or by Jack (the AI assistant). Currently:
- The `JournalEntryCard` component does not display author attribution at all (it shows date, name, location, description, and comment count).
- The `JournalEntries::Show` view does not display who created the entry.

**Future UI opportunity:** When Jack starts creating journal entries via MCP, users will want to distinguish human-authored entries from AI-authored entries. This could be addressed with:
- A small badge or tag on `JournalEntryCard` showing "by Jack" when `actor_type == "Jack"` (similar to how `TripStateBadge` shows trip states).
- An author line on the `JournalEntries::Show` detail view.

**No action needed now.** The MCP server is the only consumer of these fields today. UI attribution should be designed when the Telegram bot integration (which sends user messages through Jack) is complete, so the full range of `actor_type` values is known.

**Library reference if needed later:** `application_ui/elements/badges/flat.html` (already used as the basis for `TripStateBadge`). A new `ActorBadge` or `AuthorBadge` component could follow the same pattern.

### 2. `journal_entries.telegram_message_id` and `comments.telegram_message_id`

These are internal idempotency keys used exclusively by the MCP tools to prevent duplicate creation. They have no user-facing meaning and should **never** be displayed in the UI. No component changes needed.

---

## UI Component Library Sync Audit

The SKILL.md workflow requires that every Phlex component in `app/components/` has a corresponding `ui_library/*.yml` entry. This audit covers the full library state, not just Phase 8 changes.

### Current State

| Metric | Count |
|--------|-------|
| Phlex components (excluding `base.rb` and `icons/`) | 33 |
| `ui_library/*.yml` entries | 7 |
| Components missing from `ui_library/` | 26 |
| SKILL.md component table entries | 33 |

### Components with `ui_library/*.yml` entries (7)

| Component | YML entry | Status |
|-----------|-----------|--------|
| Sidebar | `sidebar.yml` | In sync |
| TripCard | `trip_card.yml` | In sync |
| TripStateBadge | `trip_state_badge.yml` | In sync |
| PageHeader | `page_header.yml` | In sync |
| CommentCard | `comment_card.yml` | In sync |
| ExportCard | `export_card.yml` | In sync |
| PwaInstallBanner | `pwa_install_banner.yml` | In sync |

### Components missing from `ui_library/` (26)

| Component | Type | Recommended `library_source` |
|-----------|------|------------------------------|
| NavItem | Navigation item | `application_ui/navigation/sidebar_navigation` |
| JournalEntryCard | List card | `application_ui/layout/cards` |
| JournalEntryForm | Form | `application_ui/forms/form_layouts` |
| CommentForm | Form | `application_ui/forms/textareas` |
| ReactionSummary | Inline widget | `null` (custom) |
| ExportStatusBadge | Status badge | `application_ui/elements/badges` |
| UserCard | List card | `application_ui/layout/cards` |
| UserForm | Form | `application_ui/forms/form_layouts` |
| AccessRequestCard | List card | `application_ui/layout/cards` |
| AccessRequestForm | Form | `application_ui/forms/form_layouts` |
| InvitationCard | List card | `application_ui/layout/cards` |
| InvitationForm | Form | `application_ui/forms/form_layouts` |
| TripMembershipCard | List card | `application_ui/layout/cards` |
| TripMembershipForm | Form | `application_ui/forms/form_layouts` |
| TripForm | Form | `application_ui/forms/form_layouts` |
| ChecklistCard | List card | `application_ui/layout/cards` |
| ChecklistForm | Form | `application_ui/forms/form_layouts` |
| ChecklistItemRow | List row | `application_ui/lists/stacked_lists` |
| AccountForm | Form | `application_ui/forms/form_layouts` |
| AccountDetails | Detail display | `application_ui/data_display/description_lists` |
| NoticeBanner | Feedback | `application_ui/feedback/alerts` |
| FlashToasts | Feedback | `application_ui/overlays/notifications` |
| RodauthLoginForm | Auth form | `application_ui/forms/sign_in_forms` |
| RodauthLoginFormFooter | Auth footer | `null` (custom) |
| RodauthEmailAuthRequestForm | Auth form | `application_ui/forms/form_layouts` |
| RodauthFlash | Auth feedback | `application_ui/feedback/alerts` |

The SKILL.md "Existing Project Components" table is complete at 33 entries and includes all components. The gap is only in the `ui_library/*.yml` files, where 26 of 33 components lack registry entries.

**Note:** This gap predates Phase 8 and is not caused by it. Phase 8 did not create any new components that need registration.

---

## New Components Needed for MCP Features: None

The MCP server is accessed exclusively through JSON-RPC over `POST /mcp`. There is no admin dashboard, tool configuration page, API key management UI, or MCP status page included in Phase 8. All interaction is programmatic (AI assistant or curl).

If future phases add an admin-facing MCP management interface, the following components would be candidates:

| Potential Component | Type | Library Reference |
|--------------------|------|-------------------|
| McpToolCard | List card | `application_ui/layout/cards` |
| McpRequestLog | Data table | `application_ui/lists/tables` |
| ApiKeyInput | Form element | `application_ui/forms/input_groups` |
| McpStatusBadge | Status badge | `application_ui/elements/badges` |

These are speculative and should only be built when an actual requirement exists (YAGNI).

---

## CSS and Design Token Impact: None

- `app/assets/tailwind/application.css` was not modified in this branch.
- No new CSS custom properties (`--ha-*`) were added.
- No new Tailwind classes were introduced.
- No `bin/cli app rebuild` is needed for CSS recompilation due to Phase 8 changes.

---

## Stimulus Controller Impact: None

- No new Stimulus controllers were added.
- No existing controllers were modified.
- The MCP endpoint does not serve HTML, so no Turbo Stream or Turbo Frame integration is involved.

---

## Summary of Recommendations

### Phase 8 Specific

**No recommendations.** Phase 8 is entirely API-only with zero UI surface. There are no components to review, no styling changes to evaluate, and no design system compliance to verify. The phase is clean from a UI perspective.

### Pre-existing Library Sync Debt (Not Phase 8)

| # | Issue | Effort | Priority |
|---|-------|--------|----------|
| 1 | Create 26 missing `ui_library/*.yml` entries for existing components | Medium (batch task) | Low -- backlog item |
| 2 | Regenerate `ui_library/index.html` after adding entries | One-liner | Low -- follows #1 |

This debt has accumulated across Phases 1-7 and is not attributable to Phase 8. It should be tracked as a separate housekeeping issue rather than blocking this phase.

### Future Phase Consideration (Not Phase 8)

| # | Issue | When | Effort |
|---|-------|------|--------|
| 3 | Consider an `ActorBadge` component to show Jack attribution on journal entries | When Telegram bot integration surfaces MCP-created entries in the UI | Small -- one component |
| 4 | Consider an MCP admin dashboard if operational visibility is needed | When MCP usage grows beyond development/testing | Medium -- new page + components |

---

## Overall Assessment

Phase 8 introduces **no UI changes whatsoever**. The MCP server, its 10 tools, the controller, and the database migrations are entirely backend concerns that return JSON responses to programmatic clients. No Phlex components, views, Stimulus controllers, CSS tokens, or Tailwind classes were touched.

The UI Component Library is in sync for the 7 components that have `ui_library/*.yml` entries. The 26-component registration gap is pre-existing debt from earlier phases and is unrelated to this branch.

From a UI Designer perspective, Phase 8 is **clear to merge** with no blockers, no required changes, and no design system concerns.
