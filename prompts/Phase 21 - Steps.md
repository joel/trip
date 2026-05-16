# Phase 21 — Steps (audit trail)

> Append-only log of decisions, commits, and verifications.
> Plan: [`PRPs/phase-21-audit-log.md`](../PRPs/phase-21-audit-log.md).

---

## 1. Issue + plan

- **Issue:** [#143 — Phase 21: Audit Journal — append-only, role-gated activity feed](https://github.com/joel/trip/issues/143)
- **Plan:** `PRPs/phase-21-audit-log.md` (pointer `prompts/Phase 21 - Audit Log.md`)
- **User approved the plan** and requested execution via `/execution-plan`.
- Four design ambiguities resolved with the owner before execution (PRP §1): General = superadmin-only; viewers/guests → 404; diffs = changed fields + values, no gem; Phase 21 = foundation + trip feed + live UI.

## 2. Branch

- `feature/audit-journal` (from `main`)
- Kanban: issue added blocked by missing `gh` token scope `read:project`; user asked to run `gh auth refresh -s project`. Issue #143 is the primary tracking artifact; board moves batched once scope is granted.

## 3. Task 0 — sync-dispatch spike

- `bin/rails runner` probe subscriber + caller thread-local. Result: `ran_synchronously=true`, `same_thread_as_caller=true`, `saw_caller_thread_local=true`.
- **Conclusion:** `Rails.event.notify` dispatches subscribers synchronously in the caller thread; `Current.actor` set in `ApplicationController` before_action is visible inside `AuditLogSubscriber#emit`. PRP §12.1 design validated — no fallback widening needed. No commit (spike only).

## 4. Commits

| # | SHA | Component | Notes |
|---|-----|-----------|-------|
| 1 | `652f14c` | docs | PRP + pointer + Steps scaffold (`[skip ci]`) |
| 2 | `aa4452e` | Task 1 | AuditLog model, migration, factory, spec — 19 examples |
| 3 | `ade399e` | Task 2 | Current attrs + ApplicationController/McpController wiring |
| 4 | `4f42446` | Task 3 | `changes:` enrichment of 4 update actions + AGENTS.md table |
| 5 | `220da2c` | Task 4 | AuditLog::Builder — 17 builder examples |
| 6 | `769134c` | Task 6 | AuditLogCard + RecordAuditLogJob + Clock icon — 6 examples |
| 7 | `dc7f424` | Task 5 | AuditLogSubscriber + event registry — 4 examples |
| 8 | `e9d5ae4` | Task 7 | Trips::Delete (closes trip.deleted gap) |
| 9 | `0edb055` | Task 8+10 | Policy + controller + route + view + nav — 11 examples |
| 10 | `b3b5123` | Task 9 | AuditLogChannel + Stimulus controller — 5 examples |
| 11 | `6cd7758` | Task 11 | System spec — 5 examples (rack_test) |

### Deviations / notes for self-eval

- **PRP §12.2 narrowed:** Task 0 proved `Rails.event` is synchronous, so `Current.actor` covers attribution. Adding `actor_id:` to every payload was redundant — only the dirty diff (`changes:`) needs the payload (the async writer cannot reconstruct it). Scope cut from ~8 actions to the 4 update actions.
- **Task 6 / 10 re-grouped:** `RecordAuditLogJob` broadcasts a rendered `AuditLogCard`, so the card shipped with the job (write path) to keep every commit buildable; Task 10 then added only the index view + nav (read path). Commits `769134c` then `0edb055`.
- **Task 8 + 10 combined:** the controller needs a view to render; committed together as the feed surface (`0edb055`).
- **404 vs 403 (flag #1):** `AuditLogsController` overrides the app-wide `ActionPolicy::Unauthorized → 403` with `head :not_found` so the feed's existence is not disclosed to viewers/guests. Documented in AGENTS.md.
- **Kanban blocked:** `gh` token lacks `read:project`; board moves deferred to scope grant. Issue #143 is the tracking artifact.

## 5. Validation

- `bundle exec rake project:lint` → 485 files, **0 offenses** (RuboCop + ErbLint)
- `bundle exec rake project:tests` → **760 examples, 0 failures**, 2 pending (pre-existing helper stubs, unrelated)
- `bundle exec rspec spec/system` (rack_test, CI parity) → **84 examples, 0 failures**

## 6. Runtime verification

`/product-review` against the rebuilt Docker app (dev `:async` adapter runs jobs in-process):

- `bin/cli app rebuild` + `restart` + `mail start` → health 200; new Tailwind/Stimulus/Clock-icon compiled cleanly
- Home (logged out) renders — no regression
- Email-auth login as `joel@acme.org` (superadmin) works
- Trip page shows the gated **Activity** link; feed renders the empty state (Clock icon + "No activity yet")
- **Write path proven live:** edited the Iceland trip description in the UI → `trip.updated` → `AuditLogSubscriber` → `RecordAuditLogJob` → row persisted (`Joel Azemar updated trip "Iceland Road Trip" — Description: …`, `metadata.changes` correct), actor resolved via `Current` (payload had none)
- Feed renders the row: avatar, summary, strikethrough→new diff block, relative time
- Viewer `dave@acme.org` (Iceland viewer): **0 Activity links**, direct `/activity` → **404** (log: `AuditLogPolicy#index? false` → rescue → 404). Flag #1 confirmed.
- Dark mode renders the feed correctly (only `--ha-*` tokens used)
- No runtime errors in `docker logs` (only the expected, correct `ActionPolicy::Unauthorized` rescue for the viewer)

## 7. PR + review

- Branch `feature/audit-journal` pushed; **PR [#144](https://github.com/joel/trip/pull/144)** — "Phase 21: Audit Journal — append-only, role-gated activity feed", `Closes #143`.
- CI triggered on push (lint + brakeman + bundle-audit + 760 unit + 84 system, rack_test).
- **Kanban:** board moves (Backlog→…→In Review) blocked throughout — `gh` token lacks `read:project`/`project` scope (`gh auth refresh -s project` was requested but not granted). Issue #143 + PR #144 are the tracking artifacts; board can be moved once the scope is added.
### Review round 1 — Codex bot (commit `40c6b20`)

| Comment | Severity | Assessment | Action | Resolved |
|---------|----------|------------|--------|----------|
| `builder.rb:71` — `comment.deleted` loses trip context (find_by nil after destroy!) | P1 | Valid — high-signal destructive event became an invisible app-wide row | Fixed `08316f1`: resolve trip via surviving `journal_entry_id`; regression spec | ✅ thread resolved |
| `builder.rb:77` — `reaction.removed` loses trip context (find_by nil after destroy!) | P2 | Valid — same root cause; low-signal row became app-wide | Fixed `08316f1`: `reaction_trip_id` from payload reactable; 3 regression specs | ✅ thread resolved |

Root cause: builder loaded the primary record that delete actions emit *after* `destroy!`. Fix resolves trip context from surviving related records in the payload, unconditionally (one path). Audit suite 66 examples / 0 failures, lint clean. Replies posted, both threads resolved (0 unresolved). CI green on fix `08316f1`.

PRP updated (`b435f8c`) to fold the review outcome into the plan as-built: a new §8 Edge Cases row ("Delete events emitted post-`destroy!`") and a §12.2 builder corollary (resolve `trip_id` from payload sibling IDs, never from the destroyed primary record; cover a deleted event per entity in specs). `PRPs/**` is paths-ignored, so no CI run.

## 8. Final summary

| Issue | PR | Branch | Commits | Status |
|-------|----|--------|---------|--------|
| #143 | #144 | `feature/audit-journal` | 17 (12 feature + Steps/docs + review fix `08316f1` + PRP note `b435f8c`) | In review — CI green, review round 1 resolved |

Phase 21 delivered: foundation (`AuditLog`, `Current`, `Builder`, `Subscriber`, `Job`), trip-scoped live feed (policy, controller, route, Phlex view+card, channel, Stimulus), `trip.deleted` gap closed, full spec pyramid, docs + Stitch prompt. Phase 22 deferrals unchanged (superadmin General console, search, filters, auth-event emit points).

## 9. Stitch design verification

- Stitch prompt reworked into a structure-and-scope brief (no style specs; the Stitch design system is already established) — `prompts/Phase 21 - Audit Log - Google Stitch Prompt.md`. PRP §17 annotated with an as-built note pointing to it (commit recording this in §10 below).
- Reviewed the generated screens via the Stitch MCP (project `3314239195447065678`, "Catalyst"). Three were on-brief as generated; two were off-brief and regenerated via `edit_screens` (note: `edit_screens` creates a *new* screen, leaving the original in the project for manual deletion in the Stitch UI).

| State | Screen ID | Outcome |
|---|---|---|
| Activity Feed — Desktop | `32d30c7bd52b42e78c013b0f8076578d` | ✅ on-brief |
| Activity Feed — Mobile | `d0d944b384554b64a72201d69b52592f` | ✅ on-brief |
| Low-Signal ON | `7147d9171d0e4ef5ad2b20b99c2adb1e` | ✅ on-brief |
| Empty State (regenerated) | `6ea5ba46e65145939dbab7a0af6fa576` | ✅ search/filter removed, title/overline fixed |
| Live Audit Log (regenerated) | `c974c93080304df28841a862627c08c2` | ✅ was a social/photo feed → now an audit log with the live-insert "JUST NOW" row |

- Superseded screens still present in the project (no MCP delete; manual cleanup in Stitch UI): `6b790ad118e14375ac766202cdd9d7cc` (old Empty State), `f3017fef3728453dbf700205db7bf803` (old Live Insert).
- Observation: regenerated screens render on a newer "Catalyst Glass" design-system asset and a darker shell — Stitch reinterprets the app chrome; the **page body** is the design reference, not the navigation (the production shell is already built).
