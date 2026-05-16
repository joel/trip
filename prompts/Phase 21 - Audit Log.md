# Phase 21 — Audit Journal

```
Resume this session with:
claude --resume 8c30e8c8-1fe1-4c76-910b-7aa7d70be8fe
```

**Plan / PRP:** [`PRPs/phase-21-audit-log.md`](../PRPs/phase-21-audit-log.md) — authoritative document (scoping + implementation blueprint, confidence 8/10).

This phase adds an append-only, role-gated Audit Journal: every existing `Rails.event`
mutation is captured asynchronously and shown in a live, trip-scoped Activity feed.

## Resolved scope (see PRP §1)
- General/app-wide journal = **superadmin-only** security log (data captured now, console = Phase 22).
- Trip-specific journal = **contributor-and-above**; viewers/guests → nav hidden + route **404**.
- Edit diffs = **changed fields + values, no versioning gem** (captured in the Actions layer).
- Phase 21 ships: `AuditLog` model, `AuditLogSubscriber`, async `RecordAuditLogJob`,
  trip feed with live ActionCable updates, Google Stitch prompt. Search / filters /
  superadmin console / auth-event emit points = **Phase 22**.

## Execution
Follow the `/execution-plan` skill: GitHub issue → Kanban → branch → atomic commits
→ `project:tests` + `project:system-tests` → live `/product-review` → PR → review response.

- Task 0 (spike, no commit): confirm `Rails.event` dispatches subscribers synchronously
  in the request thread so `Current.actor` is populated — record the result here.
- Task list: PRP §13. Validation gates: PRP §15. Runtime checklist: PRP §16.

## Steps audit trail
Append commits, deviations, validation and runtime results to
`prompts/Phase 21 - Steps.md` as work proceeds (project Steps convention).
