# Phase 24 — Steps (flight recorder)

Plan: [`prompts/Phase 24 Components Isolation.md`](./Phase%2024%20Components%20Isolation.md)

## 1. Issue & approval

- **Issue:** [#188](https://github.com/joel/trip/issues/188) — "Phase 24: Extract
  Checklist domain into a namespaced Packwerk pack" (label `cleanup`).
- User approved the plan: Checklist-only, full vertical slice, `Checklists::`
  namespace (engine idiom), DB tables preserved via `self.table_name`.
- Kanban: Backlog → Ready → **In Progress**.

## 4. Branch

- `feature/phase-24-checklist-pack` (off `main`).

## 7. Commits

| sha | task | rationale |
|-----|------|-----------|
| `f817870` | T1 deps | Add packwerk, packs-rails, graphwerk |
| `5238994` | T2 baseline | packwerk init; zero-violation root baseline; exclude lib/templates; .rspec require |
| `1d56aa7` | T3+T4+T5 | Extract full checklist slice into packs/checklists under `Checklists::` (relocate + namespace + external refs + specs + pack-view autoloader); one atomic unit since Zeitwerk must be globally consistent |
| `a2cf3fb` | T6 enforce | `enforce_dependencies: true` on the pack; 0 violations, no package_todo.yml |
| `5719685` | T7+T8 | packs in rake test tasks + CI; packwerk check in project:lint and CI |
| `0cde0f7` | — | Drop graphwerk (unused without graphviz binary) |

Key engineering decisions during T3/T4 (recorded for future packs):
- Namespaced models override `self.model_name` to keep un-namespaced
  route/param keys; `self.table_name` preserves DB tables (no migration).
- MCP tools pin `tool_name` to keep the public API contract stable
  (`create_checklist`, …) despite the `Checklists::Tools::*` class rename.
- Controllers routed via `scope module: :checklists` (URLs unchanged).
- Pack `app/views` registered at root namespace in `config/application.rb`
  (packs-rails autoloads pack components but not views).
- `AuditLog::Builder` maps checklist `auditable_type` to the namespaced models.

## 8. Runtime verification (/product-review)

Live verification in Docker (`bin/cli app rebuild && app restart`):

- App rebuilds and boots with the pack (health check 200).
- Namespaced models verified live: `Checklists::Checklist.table_name`
  == "checklists"; `model_name` == "Checklist" (param/route keys preserved);
  `Trip.checklists` returns `Checklists::Checklist`.
- Checklist CRUD walked in the browser as joel@acme.org on Iceland (started):
  index renders (`Checklists::Card` progress bar) → New (submit button reads
  "Create Checklist", proving the model_name override) → create
  ("Checklist created.") → show → add section ("Section added.") → add item
  ("Item added.") → **toggle item live** (Turbo Stream replace; DB shows
  `completed=true`) → delete ("Checklist deleted.").
- Activity feed at `/trips/:id/activity` logged the events: "created checklist
  …", "deleted a checklist" — audit pipeline + namespaced `auditable_type` OK.
- Dark mode toggle works (`<html class="dark">`).

Notes (pre-existing, not caused by this change):
- `db:reset` seeds fail on image attach (`Aws::S3::Errors::NotFound`) —
  SeaweedFS/S3 not configured in dev (#44). After `db:reset`, restart the app
  so Puma reconnects to the recreated SQLite file.
- Full local system suite under Selenium is flaky (different specs fail each
  run; each passes in isolation). CI runs with `TEST_BROWSER=rack_test`, which
  is green (93 examples, 0 failures).

## 11. PR review

_pending_

## 12/14. Final summary

_pending_
