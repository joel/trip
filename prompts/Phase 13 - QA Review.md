# QA Review -- feature/catalyst-glass-design-system

**Branch:** `feature/catalyst-glass-design-system`
**Phase:** 13
**Date:** 2026-03-27
**Reviewer:** Claude (adversarial QA pass)

---

## Test Suite Results

- **Unit/integration tests:** 479 examples, 0 failures, 2 pending
- **System tests:** 14 examples, 1 failure (see D1 below)
- **Linting:** 375 files inspected (RuboCop), 15 ERB files -- no offenses

---

## Acceptance Criteria

- [x] Phase 0: CSS tokens, fonts, variables loaded via `application.css` -- PASS
- [x] Phase 1: Layout, sidebar, mobile nav components render correctly -- PASS
- [x] Phase 2: Dashboard/home redesign with hero welcome, quick actions, info cards -- PASS
- [x] Phase 3: Trip cards with cover image gradients and editorial layout -- PASS
- [x] Phase 4: Trip detail hero cover with gradient overlay and state badge -- PASS
- [x] Phase 5: Journal entries editorial layout with images, comments, reactions -- PASS
- [x] Phase 6: Form components use `ha-input`, `ha-button` classes consistently -- PASS
- [x] Phase 7: Auth pages (login, create account) use glass panels -- PASS
- [x] Phase 8: User cards with avatar layout, account details with role chips -- PASS
- [x] Phase 9: Checklist cards with progress bars -- PASS
- [x] Phase 10: Dark mode toggle works, tokens switch correctly -- PASS
- [ ] System tests pass -- FAIL (1 failure, see D1)

---

## Defects (must fix before merge)

### D1: System test failure -- TripStateBadge `uppercase` CSS breaks Capybara text matching

**File:** `app/components/trip_state_badge.rb:27` and `spec/system/trips_spec.rb:34`

**Steps to reproduce:**
```bash
mise x -- bundle exec rspec spec/system/trips_spec.rb:30
```

**Expected:** Test passes -- `expect(page).to have_content("Planning")` finds the text.

**Actual:** Test fails. The `TripStateBadge` renders `@state.capitalize` ("Planning") in the HTML, but applies CSS `uppercase` (`text-[10px] font-bold uppercase tracking-widest`). Capybara with a JS driver (headless Chrome) sees the computed visible text as "PLANNING", not the DOM text "Planning". The error message confirms: "it was found 1 time using a case insensitive search."

**Recommended fix:** Either:
1. (Preferred) Remove the CSS `uppercase` from the badge and use `@state.upcase` in Ruby instead, so DOM text matches visual text.
2. Or update the spec to use case-insensitive matching: `expect(page).to have_content(/planning/i)`.

Option 1 is cleaner because it keeps DOM and visual text in sync, avoiding this class of issues across all badge usages.

---

## Edge Case Gaps (should fix or document)

### E1: `ha-card` hover lift on non-interactive cards

**Risk if left unfixed:** The `.ha-card` CSS class applies `transform: translateY(-4px)` on hover to all cards, including info/detail cards that are not clickable links (e.g., trip info card on show page, account details card). This gives users a visual affordance suggesting the card is interactive when it is not, violating user expectations.

**Recommendation:** Add a `.ha-card-static` variant (or `.ha-card-interactive`) to distinguish clickable cards from display-only cards. Apply hover lift only to interactive cards.

### E2: External font loading dependency

**Risk if left unfixed:** `application.css` line 1 loads Inter, Space Grotesk, and JetBrains Mono from Google Fonts CDN. If Google Fonts is unavailable (corporate firewall, offline PWA usage), the fallback chain (`"Segoe UI", ui-sans-serif, system-ui, sans-serif`) will kick in, but the page may show a FOUT (Flash of Unstyled Text) or layout shift while waiting for the font request to time out.

**Recommendation:** Add `font-display: swap` to the Google Fonts URL (`&display=swap` -- already present), and consider self-hosting the fonts for the PWA use case.

### E3: Mobile bottom nav touch target height

**Risk if left unfixed:** The mobile bottom nav tabs use `py-2` (8px top/bottom padding). Combined with the icon (16px) and label text (10px), the total touch target may fall below the 44px minimum on some devices. The nav item also uses `gap-0.5` (2px) between icon and label, making the tappable area compact.

**Recommendation:** Increase `py-2` to `py-3` on mobile nav tabs to ensure minimum 44px touch targets.

### E4: PWA install banner "Install" button touch target below 44px

**Risk if left unfixed:** The PWA install button measures 73x40px, failing the 44px height minimum for comfortable mobile touch targets.

**Recommendation:** Increase button padding to reach at least 44px height.

---

## Observations

- **Design token coverage is comprehensive.** All 35 changed files consistently use `var(--ha-*)` CSS custom properties. No hardcoded colors were found outside of the token system (except the Google Fonts gradient hero which uses gradient colors derived from tokens).

- **Dark mode is well-implemented.** The `.dark` class on `<html>` properly flips all token values. Tested visually -- sidebar, cards, hero covers, badges, forms, and background decorations all render with correct contrast in dark mode.

- **`@source` directives added for Tailwind v4.** Lines 3-5 in `application.css` add `@source "../../views"`, `@source "../../components"`, and `@source "../../../app/javascript"` to ensure Tailwind v4 scans all Phlex component files for class names. This is correct and necessary for JIT compilation.

- **Glass morphism (`ha-glass`) is used sparingly and effectively.** Applied only to login panel, mobile top bar, and mobile bottom nav -- not overused. The dark mode variant correctly reduces transparency and increases blur.

- **Background decorations in layout** use `pointer-events-none` and `fixed` positioning with `-z-10`, which correctly prevents them from interfering with page interactions.

- **`prefers-reduced-motion` is respected.** The CSS includes a media query at line 378 that disables animations and transitions for users who prefer reduced motion.

- **All form components use consistent styling.** Every form across the app uses `ha-input` for fields, `ha-button ha-button-primary` for submit buttons, and `text-[var(--ha-on-surface-variant)]` for labels. Error displays use `ha-error-container` and `ha-error` tokens.

- **No file exceeds 500 lines.** Largest file is `application.css` at 407 lines. Sidebar at 260 lines, home view at 244 lines, trip show at 237 lines.

---

## Regression Check

- **Trip CRUD** -- PASS (trips index, show, edit form all render correctly with new design)
- **Journal entries** -- PASS (entry cards with images, detail view with body/images/reactions/comments)
- **Authentication** -- PASS (login flow via email auth works end-to-end through browser)
- **Comments & reactions** -- PASS (seeded comments render with user names, timestamps, edit/delete; reactions display correctly)
- **Checklists** -- PASS (progress bar renders with correct percentage, items count)
- **Access requests** -- PASS (admin view shows pending/approved/rejected requests with action buttons)
- **MCP Server** -- PASS (see table below)

---

## MCP Server

| Test | Expected | Actual |
|------|----------|--------|
| tools/list returns 12 tools | 12 | 12 -- PASS |
| Auth: no key | 401 | 401 -- PASS |
| Auth: wrong key | 401 | 401 -- PASS |
| Auth: wrong content-type | 415 | 415 -- PASS |
| Auth: malformed JSON | -32700 | -32700 Parse error -- PASS |
| Unknown tool name | error response | -32602 "Tool not found" -- PASS |
| Wrong JSON-RPC method | "Method not found" | -32601 "Method not found" -- PASS |
| get_trip_status (started) | success with trip data | success, returns trip JSON -- PASS |
| create_journal_entry (started) | success | success, entry created -- PASS |
| create_journal_entry (finished) | "not writable" error | "Trip 'Japan Spring Tour' is not writable (state: finished)" -- PASS |
| create_journal_entry (cancelled) | "not writable" error | "Trip 'Norway Fjords' is not writable (state: cancelled)" -- PASS |
| create_comment (finished) | success (commentable) | success, comment created -- PASS |
| upload_journal_images (invalid b64) | "Invalid base64" error | "Invalid base64 data for image 0" -- PASS |
| upload_journal_images (non-image) | "Invalid content type" error | "Invalid content type \"text/html\" for image 0" -- PASS |
| upload_journal_images (> 5 images) | "Too many" error | "Too many images (6). Maximum is 5 per call" -- PASS |

---

## Mobile (393x852) -- Code Review

Direct mobile viewport testing was not possible due to `agent-browser` lacking viewport resize on this platform. The following assessment is based on code review of responsive classes and CSS:

| Page | Overflow | Responsive Classes | Touch Targets | Notes |
|------|----------|-------------------|---------------|-------|
| Home (logged out) | OK | `md:text-5xl` scales down on mobile | See E3/E4 | Desktop overflow check: OK |
| Login | OK | `max-w-md` constrains form width, `ha-input` is full-width | OK | Glass panel scales properly |
| Trips index | OK | `md:grid-cols-2` falls back to single column | OK | Cards stack vertically |
| Trip show | OK | `md:h-96` hero scales to `h-72` on mobile, `md:text-6xl` to `text-4xl` | OK | `flex-wrap gap-3` on action buttons |
| Journal entry | OK | `md:grid-cols-3` images fall to `grid-cols-2` | OK | |
| Checklist | OK | Single-column card layout | OK | |
| Users | OK | `md:grid-cols-2` falls to single column | OK | |

**Mobile navigation verified in code:**
- `MobileTopBar` uses `md:hidden` (visible only on mobile), `fixed top-0 z-40`, `h-16`
- `MobileBottomNav` uses `md:hidden` (visible only on mobile), `fixed bottom-0 z-50`, glassmorphism
- Desktop sidebar uses `hidden md:flex` (hidden on mobile)
- Main content area has `pt-16 pb-20 md:pt-0 md:pb-0` to account for mobile nav bars

**Potential mobile concern:** The `py-2` on mobile bottom nav tabs may not meet 44px touch targets (see E3).

---

## Summary

The Catalyst Glass Design System is well-implemented across all 10 phases. The design token system is comprehensive and consistently applied. Dark mode works correctly. All MCP endpoints continue to function properly.

**Blocking issue:** 1 system test failure (D1) must be fixed before merge -- the `TripStateBadge` CSS `uppercase` class causes Capybara to see "PLANNING" instead of "Planning".

**Non-blocking:** 4 edge case gaps (E1-E4) should be addressed before or after merge as the team prefers.
