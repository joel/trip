# Phase 16 - UI Designer Review: Onboarding Improvements

**Date:** 2026-04-18
**Branch:** `feature/phase16-onboarding-improvements`
**PR:** #103 -- Phase 16: Onboarding improvements
**Reviewer:** UI Designer Agent
**Scope:** Remove the Sign-in card on the logged-out homepage, add unified onboarding flash messaging, and verify no drift in the design system.

---

## 1. Executive Summary

Phase 16 is a predominantly back-end phase (Rodauth hooks, AccessRequest validations, migration). The only structural view change is `app/views/welcome/home.rb`, which collapses a two-column `md:grid-cols-2` layout down to a single centred access card wrapped in `mx-auto w-full max-w-md`. All flash messaging is surfaced through the existing `Components::FlashToasts` component rendered by the application layout -- no new UI components were introduced and none of the existing Phlex components in `app/components/*.rb` were modified by this branch.

**Overall Assessment:** PASS with a small set of polish recommendations (all 🟡 Medium / 🟢 Low). No 🔴 Critical defects. The card renders cleanly at every tested viewport, respects the design tokens, and the redirect flash copy is consistent across both onboarding redirect paths.

### Findings at a glance

| Severity | Count |
|----------|-------|
| 🔴 Critical / Broken / Defect | 0 |
| 🟠 High | 0 |
| 🟡 Medium | 3 |
| 🟢 Low | 4 |
| ✅ Verified OK | 9 |

---

## 2. Screenshots Captured

All screenshots live under `/tmp/phase16-ui-review/`:

| File | What it shows |
|------|---------------|
| `01_home_logged_out_desktop.png` | Home logged-out, 1440x900 |
| `02_home_logged_out_tablet.png` | Home logged-out, 768x1024 |
| `03_home_logged_out_mobile.png` | Home logged-out, 390x844 |
| `04_login_desktop.png` | `/login` reference (single-card pattern A) |
| `05_create_account_desktop.png` | `/create-account` reference (single-card pattern A) |
| `06_request_access_desktop.png` | `/request-access` reference (full-width card pattern B) |
| `07_home_after_unknown_login.png` | Flash toast after unknown-login redirect |
| `08_home_after_missing_token.png` | Flash toast after missing-token redirect |
| `12_first_submit.png` | Toast after successful access-request submission |
| `16_duplicate_submit.png` | Inline "already has a pending request" error |
| `18_alice_submit.png` | Inline "already registered" error |
| `19_home_dark.png` | Home logged-out in dark mode |
| `20_home_fullhd.png` | Home logged-out, 1920x1080 (surfaces layout drift) |

---

## 3. Design System Conformance

### 3.1 Tokens & Utility Classes

Every class used in `app/views/welcome/home.rb#render_access_card` and `app/views/welcome/home.rb#render_logged_out` is already present in the compiled Tailwind bundle. No JIT rebuild concerns.

| Class / Token | Source | Status |
|---------------|--------|--------|
| `ha-card`, `ha-rise`, `ha-overline`, `ha-button`, `ha-button-primary` | design-system classes | ✅ OK |
| `font-headline`, `text-4xl`, `md:text-5xl`, `text-2xl`, `text-lg`, `text-sm` | existing typography | ✅ OK |
| `mx-auto`, `w-full`, `max-w-md` | already used on `/login`, `/create-account` wrappers | ✅ OK |
| `space-y-12`, `mt-2`, `mt-3`, `mt-6`, `p-6` | existing rhythm tokens | ✅ OK |
| `var(--ha-on-surface-variant)` | existing CSS variable | ✅ OK |
| `animation-delay: 160ms` | inline-style, matches Phase 15 usage | ✅ OK |

No new classes were introduced. Screenshot: `01_home_logged_out_desktop.png`.

### 3.2 `render_access_card` structure vs project conventions

```
ha-card p-6 ha-rise  (animation-delay: 160ms)
  ha-overline  "Access"
  h2 (font-headline text-2xl font-bold, mt-2)  "Request an invitation"
  p  (text-sm var(--ha-on-surface-variant), mt-3)  "This is an invite-only..."
  div (mt-6)
    a.ha-button.ha-button-primary  "Request Access"
```

Matches the card recipe documented in `.claude/skills/ui-designer/SKILL.md` exactly (overline → title → body → action). ✅ OK.

### 3.3 Flash surface consistency

Both redirect paths (Task 2 unknown-login, Task 3 missing-token) surface the flash through the shared `Components::FlashToasts` component in the application layout. No new alert UI was introduced. Screenshots `07_home_after_unknown_login.png` and `08_home_after_missing_token.png` show identical styling and copy.

- "Invitation required. Request access below." → rose/alert toast  ✅
- "Welcome! Your access request has been submitted. We'll be in touch!" → emerald/notice toast (from access-request creation) ✅
- "Welcome! Your account is ready." → toast fires on invited-signup auto-login (code path verified, not directly screenshotted because it requires a live invitation token outside the scope of this review)

Inline form errors (`render_errors` in `Components::AccessRequestForm`) use the project's `--ha-error` / `--ha-error-container` tokens -- consistent styling. Screenshots `16_duplicate_submit.png` and `18_alice_submit.png`.

---

## 4. Findings

### 🟡 Medium

#### M-1. Heading and card are visually misaligned on wide viewports

**Screenshots:** `01_home_logged_out_desktop.png` (1440), `20_home_fullhd.png` (1920).

The layout produces a "floating" feel at wide viewports: the "Welcome to Catalyst" heading sits at the left edge of the `mx-auto max-w-5xl` column, while the access card sits centred within the same column, roughly 400px to the right of the heading. On 1920x1080 the card is visibly detached from the heading -- the eye reads "heading on the left, orphan card on the right."

**Why it matters.** The three comparable single-card surfaces in the app use different centring approaches:

| Surface | Wrapper | Card position |
|---------|---------|---------------|
| `/login` | `flex min-h-[70vh] items-center justify-center` with `w-full max-w-md` inside | Heading + card both centred, stacked |
| `/create-account` | same pattern | Heading + card both centred, stacked |
| `/request-access` | `space-y-6` inside `max-w-5xl` | Heading + full-width card, both left-aligned |
| `/` (Phase 16, new) | `space-y-12` with `mx-auto max-w-md` on card only | Heading left, card centred -- **mixed axes** |

The Phase 16 home page sits in a fourth pattern that matches neither reference. Pattern A (flex-centred) would align the heading + card stack on one axis; Pattern B (full-width card) would preserve the dashboard-style left-aligned heading.

**Recommendation.** Two options, both design-system-safe:

1. **Pattern A consistency (preferred):** wrap both the heading `section` and the card in a `mx-auto max-w-md` block -- the heading then centres alongside the card and the whole unit reads as a single CTA moment.
2. **Keep heading dashboard-style, widen the card:** drop `max-w-md` on the card and let it span the `max-w-5xl` column like `/request-access` does. Alignment preserved, but the card becomes a banner rather than a compact CTA -- heavier visual weight than the current balance.

The plan (`Phase 16 Onboarding Improvements.md` section 8.6) cites "single centred card, not a full-width banner" as the intent -- option 1 honours that intent while fixing the alignment drift.

#### M-2. `ha-rise` stagger is no longer meaningful with a single card

**Screenshot:** `01_home_logged_out_desktop.png`.

The card retains `animation-delay: 160ms` from the former two-card layout. With only one card left, the delay is a 160ms pause between the page's `ha-fade-in` (hero heading, 0ms) and the single card's rise -- a choreographed stagger with nothing to stagger against.

**Recommendation.** Drop the `animation-delay: 160ms` inline style on the access card (or reduce it to `80ms` for a lighter hand-off from heading-fade to card-rise). This is a low-risk polish change; the animation pipeline already tolerates zero delay.

#### M-3. UI library has many missing entries beyond Phase 16 scope

The `ui_library/` registry currently covers 21 of 43 Phlex components in `app/components/`. The logged-out onboarding surface specifically depends on four components that had no YAML entries before this review:

- `Components::FlashToasts` (drives the Phase 16 redirect toasts)
- `Components::NoticeBanner` (inline success banner used on other surfaces)
- `Components::RodauthFlash` (flash panel inside `/login`, `/create-account`, etc.)
- `Components::AccessRequestForm` (renders Phase 16's new duplicate-error messages)
- `Components::AccessRequestCard` (admin review card; indirectly affected by Phase 16's uniqueness rule)

**Action taken during this review.** I created the five YAML entries listed above (see section 6 "UI Library Sync Status"). 17 other components remain undocumented; they are unchanged by Phase 16 and flagged for a future backlog task, not blocking this PR.

### 🟢 Low

#### L-1. `flash[:alert]` toast copy hardcodes "Action needed" heading

**Screenshot:** `07_home_after_unknown_login.png`.

`Components::FlashToasts#render_alert_toast` hardcodes `p(class: "text-sm font-semibold") { "Action needed" }` above the actual flash message. For the Phase 16 flash "Invitation required. Request access below." this produces:

```
Action needed
Invitation required. Request access below.
```

The combination is redundant ("Action needed: invitation required" duplicates the imperative tone) and "Action needed" is generic enough that it could be omitted for some flash types. This is a pre-existing pattern -- not introduced by Phase 16 -- but Phase 16 exercises it for the first time on the home surface.

**Recommendation.** Not blocking. Worth a follow-up to either (a) drop the hardcoded heading in favour of just the message, or (b) pass a heading override into the component so the Phase 16 copy can read cleaner. Keep the emerald variant ("All set") which still adds value for success toasts.

#### L-2. Tablet viewport padding feels tight below the card

**Screenshot:** `02_home_logged_out_tablet.png`.

At 768x1024, the `space-y-12` between the heading and the card uses its full 48px, but the card's bottom edge sits about 730px below the card -- a large negative space that reads as "unfinished page" on tablet. The desktop viewport has a similar proportional gap but the visual weight of the sidebar and overall canvas absorbs it; on tablet the emptiness is more obvious.

**Recommendation.** Not blocking. A visually-centred single card (Pattern A) would naturally balance the vertical whitespace.

#### L-3. `render_access_card` is duplicated code across logged-out and logged-in render paths

The method `render_access_card` lives on the same `Views::Welcome::Home` class that also renders a complete logged-in dashboard (hero welcome, quick actions, active trip section, info cards). The class is 229 lines and has two independent view graphs sharing very little. This isn't a Phase 16 defect -- it's pre-existing -- but the removal of `render_signin_card` is a good moment to consider whether the logged-out branch should be split into a dedicated `Views::Welcome::LoggedOut` component.

**Recommendation.** Not blocking. Worth flagging as a refactor candidate.

#### L-4. `access_request_form.yml` description uses em-dash character

When I wrote the new YAML entry for `access_request_form.yml`, I used the em-dash `—` (U+2014) in the description: `"is already registered -- please sign in"`. The codebase's commit-msg hook (`TrailingWhitespace` and content checks) doesn't enforce ASCII, but for consistency with the rest of the YAML files I used `--` double-hyphen in the final content. Confirming after-the-fact that no other YAML uses U+2014 either. ✅ OK.

### ✅ Verified OK

| # | Area | Evidence |
|---|------|----------|
| V-1 | Card uses `ha-card` + `p-6` + `ha-rise` exactly as documented in SKILL.md | source: `app/views/welcome/home.rb` lines 197-211 |
| V-2 | Overline uses `ha-overline` token | source: line 198 |
| V-3 | Heading uses `font-headline text-2xl font-bold mt-2` (card-level) | source: line 199 |
| V-4 | Body paragraph uses `text-sm var(--ha-on-surface-variant)` | source: line 202 |
| V-5 | Primary action uses `ha-button ha-button-primary` | source: line 208 |
| V-6 | Dark mode renders cleanly (tokens swap) | screenshot `19_home_dark.png` |
| V-7 | Flash toasts render via `Components::FlashToasts` (no new flash surface) | screenshots `07`, `08`; layout `app/views/layouts/application_layout.rb` line 22 |
| V-8 | Inline form errors use `--ha-error-container` / `--ha-error` tokens | screenshots `16`, `18`; source `app/components/access_request_form.rb` line 32 |
| V-9 | Mobile viewport shows card well-centred above bottom nav | screenshot `03_home_logged_out_mobile.png` |

---

## 5. Comparison: Logged-out Single-Card Surfaces

Four logged-out surfaces present a single primary CTA. Visual behaviour summary:

| Surface | Container pattern | Vertical centring | Heading alignment | Card width |
|---------|-------------------|-------------------|-------------------|------------|
| `/login` | `flex min-h-[70vh]` + `max-w-md` | Yes (70vh flex) | Centred above card | 448px |
| `/create-account` | `flex min-h-[70vh]` + `max-w-md` | Yes | Centred above card | 448px |
| `/request-access` | `space-y-6` in `max-w-5xl` | No | Left-aligned | Full column |
| `/` **(Phase 16)** | `space-y-12` + `mx-auto max-w-md` on card | No | **Left-aligned** | 448px |

**Consistency verdict.** The new home pattern is **closer to** but not identical to `/login` / `/create-account`. It differs on one axis (heading left-aligned vs centred above card). See finding **M-1**.

The plan's claim in section 8.6 ("mx-auto max-w-md matches the form's visual width on /request-access") is slightly off -- `/request-access` actually renders a full-width card, not a 448px one. The chosen width does however match `/login` and `/create-account`, which is a cleaner alignment argument.

---

## 6. UI Library Sync Status

### 6.1 `ui_library/README.md` status

**Exists:** Yes (`/home/joel/Workspace/Workanywhere/catalyst/ui_library/README.md`).

**Content quality:** OK. The README describes the YAML entry format, how to browse the reference library, and the workflow for adding new entries. No Phase 16 updates required -- the README documents the registry structure, not the inventory itself.

**No README edits made by this review.** The README was already accurate and current.

### 6.2 Inventory coverage

At review start:
- `app/components/*.rb` (excluding `base.rb`): **42 Phlex components**
- `ui_library/*.yml`: **21 YAML entries**
- Missing: **22 components** (one orphan entry `icons_bell.yml` exists for a component nested under `app/components/icons/bell.rb`)

### 6.3 Sync work performed during this review

Created five new YAML entries to cover the Phase 16 onboarding surface and directly adjacent components. Each new entry follows the project's YAML convention (component, file, library_source, library_variant, description, design_tokens, tailwind_classes):

| File | Component | Rationale |
|------|-----------|-----------|
| `ui_library/flash_toasts.yml` | `Components::FlashToasts` | Phase 16 flash toasts ("Invitation required...") surface through this |
| `ui_library/notice_banner.yml` | `Components::NoticeBanner` | Inline success banner used across the app |
| `ui_library/rodauth_flash.yml` | `Components::RodauthFlash` | Rodauth form inline flash; same design tokens |
| `ui_library/access_request_form.yml` | `Components::AccessRequestForm` | Phase 16 introduces new inline error copy in this form |
| `ui_library/access_request_card.yml` | `Components::AccessRequestCard` | Admin review card indirectly affected by Phase 16 uniqueness rules |

After sync:
- Library coverage: **26 of 42 components** (62%).
- Phase 16 onboarding surface: **100% coverage**.

### 6.4 Pending sync gaps (for follow-up, not blocking this PR)

These 17 components are still undocumented in `ui_library/`. All pre-date Phase 16 and are out of scope for this PR, but are flagged for a future audit task:

```
account_form
checklist_form
checklist_item_row
comment_form
export_status_badge
google_one_tap
invitation_card
invitation_form
journal_entry_form
nav_item
rodauth_email_auth_request_form
rodauth_login_form_footer
trip_form
trip_membership_card
trip_membership_form
user_form
webauthn_autofill
```

Plus the `app/components/icons/*.rb` tree (20 icons) has only one entry (`icons_bell.yml`). If icons are intended to be tracked in the registry, 19 entries remain missing.

**Recommendation.** Open a `cleanup` issue on the Kanban board titled something like "UI library: backfill missing YAML entries for 17 components + 19 icons" with the list above.

---

## 7. Animation Polish

The plan's own checklist called out `.ha-rise` animation-delays in a single-card context. Finding:

- **Hero heading** (`section` with `h1 + p`): inherits `.ha-fade-in` from the layout wrapper (`mx-auto max-w-5xl ha-fade-in`). Fires at 0ms.
- **Access card**: `.ha-rise` with `animation-delay: 160ms`. Fires 160ms after page load.

With two cards removed, the stagger only has two stops: layout-fade (0ms) → card-rise (160ms). This is still coherent but the 160ms feels slightly slow for a single element. See finding **M-2**.

---

## 8. Accessibility / Semantics

| Check | Result |
|-------|--------|
| Heading hierarchy: `h1` (hero) → `h2` (card) → no skipped level | ✅ OK |
| Primary action is a real `a` tag (linking to `/request-access`), not a button | ✅ OK (correct semantic: navigation, not form action) |
| Focus outline from `ha-button` preserved | ✅ OK (inherited from design system) |
| Toast dismiss button has `aria_label: "Dismiss notification"` | ✅ OK |
| Card heading `h2` font scale is readable (24px) | ✅ OK |
| Contrast: emerald-700-on-emerald-50 (notice) and rose-100-on-dark (alert) pass WCAG AA | ✅ OK |

No accessibility regressions introduced by Phase 16.

---

## 9. Responsive Behaviour

| Viewport | Screenshot | Verdict |
|----------|-----------|---------|
| Mobile 390x844 | `03_home_logged_out_mobile.png` | ✅ Card well-sized, sidebar collapsed to top/bottom nav, ample touch target |
| Tablet 768x1024 | `02_home_logged_out_tablet.png` | ✅ Card renders cleanly, slight vertical whitespace (see L-2) |
| Desktop 1440x900 | `01_home_logged_out_desktop.png` | ⚠️ Card offset vs heading (see M-1) |
| Full HD 1920x1080 | `20_home_fullhd.png` | ⚠️ Offset more pronounced (see M-1) |

---

## 10. Code Quality Notes (from the UI designer lens)

1. **`render_logged_out` is clean and minimal.** Removing `render_signin_card` reduced the logged-out branch from ~30 lines to ~18. Good simplification.
2. **No dead code.** The deleted `render_signin_card` method is fully removed; grep finds no residual references.
3. **Flash copy is consistent.** `"Invitation required. Request access below."` appears in two Rodauth hooks (`validate_invitation_token` and `before_login_attempt`) -- same exact string. Good.
4. **Form pre-fill logic for invited signups** (in `app/views/rodauth/create_account.rb`) was not altered by Phase 16 but its code path is now the primary invited-signup surface; I confirmed it still reads `invitation_token` → pre-fills email → marks readonly. The readonly hint copy "This email is linked to your invitation and cannot be changed." remains in place. ✅ OK.

---

## 11. Consolidated Defect List

Items requiring action before merge. Every 🔴 Critical finding goes here:

**Critical (🔴):**
- [ ] *(none -- no blocking defects found)*

---

## 12. Follow-up Recommendations (non-blocking)

- [ ] 🟡 M-1: Decide on heading/card alignment approach (Pattern A wrap vs widen card). The current mixed-axis layout is functional but visually inconsistent with other logged-out CTA surfaces.
- [ ] 🟡 M-2: Drop or reduce `animation-delay: 160ms` on the single access card now that it no longer stacks against a sibling.
- [ ] 🟡 M-3: Open backlog issue for UI library backfill (17 components + 19 icons still undocumented).
- [ ] 🟢 L-1: Consider softening the hardcoded "Action needed" heading in `Components::FlashToasts` -- redundant with "Invitation required" style copy.
- [ ] 🟢 L-2: Revisit tablet vertical rhythm if M-1 is addressed (likely resolved by Pattern A).
- [ ] 🟢 L-3: Long-term refactor candidate: split `Views::Welcome::Home` into logged-in and logged-out view classes.

---

## 13. Sign-off

**UI Designer Review Verdict:** **APPROVED for merge.** No Critical or High findings. The Phase 16 UI changes are minimal, consistent with the design system, and do not regress any existing surface. The three Medium findings are polish opportunities that can be handled in a follow-up PR without blocking the Phase 16 back-end fixes.

**UI Library:** Synced for the Phase 16 onboarding surface; broader backfill logged for future work.

---

## Skill Self-Evaluation

**Skill used:** `ui-designer`

**Step audit:**

- **Step "Search the library for matching components"** -- partially unused. Phase 16 introduced no new components, so no library lookup was needed for new surfaces. The step became instead "audit existing YAML coverage", which is a different (still valuable) activity.
- **Step "Build the Phlex component"** -- not applicable; no new components built. The skill's core workflow assumes build-time context; for pure review phases, the "Workflow" section could branch on review-mode.
- **Step "Update `ui_library/`"** -- applied both ways: for Phase 16 I backfilled five missing entries rather than adding for a new component. The skill doesn't document this "backfill" pattern explicitly.
- **Agent-browser session instability** -- the browser daemon occasionally lost state between commands (one run ended up on `/login` with a stray email value from a prior fill). Worked around by closing and restarting the session. Not a skill defect, but worth noting for future multi-step flows: prefer `&&` command chaining over sequential single commands when state matters.
- **No commands produced unexpected errors** aside from the browser state issue above. No deviations from the skill's prescribed workflow that weren't documented.

**Improvement suggestion:** Add a short "Review mode" section to `.claude/skills/ui-designer/SKILL.md` that documents the alternate workflow for UI review phases:
1. Identify touched views/components vs main
2. Compare against library YAML coverage (backfill gaps for the reviewed surface)
3. Take agent-browser screenshots at 3 viewports (mobile/tablet/desktop) plus dark mode
4. Classify findings using Critical/High/Medium/Low/Verified-OK
5. Write the report to `prompts/Phase X - UI Designer Review.md`

This would reduce the ambiguity when the skill is triggered for review rather than build.
