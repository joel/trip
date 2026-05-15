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

- _pending_

## 6. Runtime verification

- _pending_

## 7. PR + review

- _pending_
