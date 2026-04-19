Consolidated Critical Findings — Phase 16 Deep QA

  All 5 review reports are on disk at prompts/Phase X - {Name}.md.

  Total 🔴 Critical findings: 6 (across QA + UX + UI Polish). Security and UI Designer found 0 Critical but flagged notable Highs worth bundling.

  ---
  🔴 Critical — must fix before merge

  ┌─────┬─────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┬────────────────────────────────────────────────────────┐
  │  #  │ Source  │                                                        Finding                                                        │                          File                          │
  ├─────┼─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
  │     │         │ Null-byte email crashes /request-access with HTTP 500. AccessRequest#email_not_already_active runs a DB query with    │                                                        │
  │ C1  │ QA      │ the raw input before format validation rejects it; SQLite raises StatementInvalid and the controller doesn't rescue   │ app/models/access_request.rb:22-34                     │
  │     │         │ it. Trivial fuzz vector.                                                                                              │                                                        │
  ├─────┼─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ C2  │ QA      │ Login + create-account redirects use HTTP 302 instead of 303. RFC 7231-strict clients (curl -L, some API consumers)   │ app/misc/rodauth_main.rb (both before_login_route +    │
  │     │         │ preserve POST method on 302 → re-POST to / → 404. Should be 303 See Other.                                            │ validate_invitation_token)                             │
  ├─────┼─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ C3  │ UX      │ GET /create-account without a token renders a "honeypot" form. Users type their email and click "Create Account" only │ app/misc/rodauth_main.rb — needs                       │
  │     │         │  to be silently bounced; no upfront warning. GET should redirect to / too (not just POST).                            │ before_create_account_route redirect                   │
  ├─────┼─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ C4  │ UX      │ Invited signup says "Welcome BACK, &lt;name&gt;" to a user who has never been here. The word "back" is wrong on first │ app/views/welcome/home.rb:31 — gate on sign_count or   │
  │     │         │  visit.                                                                                                               │ change copy                                            │
  ├─────┼─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
  │     │ UI      │ Flash toasts overlap the mobile top bar AND hero H1 at ≤393 px. max-w-sm (384 px) inside a 393 px viewport leaves 9   │ app/components/flash_toasts.rb —                       │
  │ C5  │ Polish  │ px gutter after right-6; top-6 places the toast on top of the 64 px fixed top bar and the "Welcome to Catalyst" hero. │ max-w-[calc(100vw-3rem)] md:max-w-sm and top-20        │
  │     │         │                                                                                                                       │ md:top-6                                               │
  ├─────┼─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ C6  │ UI      │ At 1920+ viewports the logged-out home feels abandoned. 65 %+ of canvas is empty below the 448 px card. Cap the       │ app/views/welcome/home.rb — narrow max-w-5xl or add    │
  │     │ Polish  │ logged-out container or add a below-the-fold supplementary block.                                                     │ content                                                │
  └─────┴─────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴────────────────────────────────────────────────────────┘

  ---
  Notable non-Critical findings worth bundling

  These were flagged 🟠 High but reinforce or connect to the Criticals above. Worth addressing in the same PR if possible:

  - Security Finding 1 + 2 (🟠 High): The /login response differential (200 + body vs 302 empty) and the /request-access inline "already registered" / "pending request" messages are account
  enumeration oracles. Undermines the invite-only threat model. Relates directly to C3 (users being told their state at the wrong moment).
  - UX Sidebar "Create account" link (🟠 High): Logged-out visitors still see a sidebar "Create account" link that now dead-ends at the redirect-loop we built. Either remove, re-label, or link to
  /request-access.
  - UX "Create account" page subcopy (🟠 High): Says "we will verify it before you log in" — false for invited users who now auto-verify. Must be conditional or removed. This matches QA D4.
  - UX Accessibility (🟠 High): Flash toasts have no role="alert"/aria-live; inline form errors have no role="alert"/aria-invalid/aria-describedby. Screen readers don't announce any of the Phase 16
  feedback.
  - QA D3 / Security Finding 3 (🟠 High): Mixed-case existing user (Alice@Acme.Org typed instead of alice@acme.org) hits the unknown-login redirect → permanent lockout until they remember the exact
  casing. User model needs normalizes :email + Rodauth normalize_login override.

  ---
  Clean

  - Security: 0 Critical. Brakeman clean, bundle-audit clean, no hard-coded secrets, all 6 invitation-token bypass attempts properly rejected, CSRF intact, MCP endpoint untouched.
  - UI Designer: 0 Critical. Design system tokens consistent. Library synced (+5 YAML entries; flash_toasts, notice_banner, rodauth_flash, access_request_form, access_request_card).
  - QA happy-path + MCP matrix: all 18 verified OK including dedupe, concurrency, CSRF, token hijack blocking, case-insensitive dedupe in AccessRequest, rejected-can-resubmit.

  ---
  Recommended response

  Six Criticals — three are copy/config tweaks (C2, C3, C4), one is a stray SQL path (C1), two are CSS/layout (C5, C6). All land on 3-4 files. Propose one follow-up PR on this branch with atomic
  commits per finding; I estimate ~1-2 h of implementation + fresh runtime verification.

  Want me to proceed with the fix pass in the same atomic-commit pattern?

QA Round 2 — Summary

  6 GitHub issues opened, 6 atomic commits pushed, all on PR #103.

  ┌─────────────────────────────────────────┬───────────────────┬─────────────────────────────────────────────────────────────────────────────────────┐
  │                  Issue                  │      Commit       │                                         Fix                                         │
  ├─────────────────────────────────────────┼───────────────────┼─────────────────────────────────────────────────────────────────────────────────────┤
  │ https://github.com/joel/trip/issues/104 │ b59b334           │ email_safe_for_query? guard stops null-byte email from reaching DB (HTTP 500 → 422) │
  ├─────────────────────────────────────────┼───────────────────┼─────────────────────────────────────────────────────────────────────────────────────┤
  │ https://github.com/joel/trip/issues/105 │ b326d09           │ Both onboarding redirects now request.redirect "/", 303                             │
  ├─────────────────────────────────────────┼───────────────────┼─────────────────────────────────────────────────────────────────────────────────────┤
  │ https://github.com/joel/trip/issues/106 │ 71e96b0           │ New before_create_account_route hook redirects GET without valid token              │
  ├─────────────────────────────────────────┼───────────────────┼─────────────────────────────────────────────────────────────────────────────────────┤
  │ https://github.com/joel/trip/issues/107 │ c238863           │ "Welcome back" → "Welcome," + 3 dependent specs updated                             │
  ├─────────────────────────────────────────┼───────────────────┼─────────────────────────────────────────────────────────────────────────────────────┤
  │ https://github.com/joel/trip/issues/108 │ c3a714b + eca1b34 │ top-20 md:top-6 + w-[calc(100vw-3rem)] max-w-sm responsive toast                    │
  ├─────────────────────────────────────────┼───────────────────┼─────────────────────────────────────────────────────────────────────────────────────┤
  │ https://github.com/joel/trip/issues/109 │ c5939fa           │ Single mx-auto max-w-md column wraps hero + card; stale stagger removed             │
  └─────────────────────────────────────────┴───────────────────┴─────────────────────────────────────────────────────────────────────────────────────┘

  Verification

  - Suites: 588 non-system + 65 system = 653 examples, 0 failures. Lint clean (0 offenses on 425 files).
  - Live curl + agent-browser:
    - C1 null byte POST → HTTP 422 ✓
    - C3 GET /create-account no token → HTTP 303 → / ✓
    - C4 live invited signup shows "Welcome, phase16r2" ✓
    - C5 computed styles at md+ viewport show top:24px + maxWidth:384px ✓
    - C6 hero + access card share the same centred 448px column ✓

  Docs

  - prompts/Phase 16 - Steps.md updated with Steps 11–12 covering deep-QA dispatch, consolidated findings, and round-2 fixes.

  Deferred (non-blocking)

  - Security's 2 High account-enumeration findings (login response differential + inline error disclosure) — not fixed here since they require a product decision (tighten message vs keep UX clarity).
   Worth a separate issue + discussion.
  - UX's 12 High findings (accessibility, sidebar dead-end, subtitle copy) — candidates for a Phase 17 follow-up PR.

  Ready for review.