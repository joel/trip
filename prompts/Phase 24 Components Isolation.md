# PRP: Phase 24 — Checklist Pack Extraction (Packwerk, engine-style)

> **Scope (approved):** Extract **only the Checklist domain** into a fully
> namespaced Packwerk pack — `packs/checklists/` under the `Checklists::`
> module — as a **complete vertical slice** (models, actions, policies,
> subscriber, controllers, Phlex components + views, MCP tools, specs,
> factories). Treat it as a **pre-Rails-Engine extraction**: the pack is a
> self-contained unit that could later be lifted into an engine.
>
> **Namespace (approved):** `Checklists::` (engine idiom). DB tables preserved
> via `self.table_name` — **no migration**.
>
> This supersedes the multi-pilot plan; Export and all other domains are
> deferred (see §9 roadmap).

---

## 1. Goal & shape

One module, `Checklists`, populated from several autoload roots inside the pack:

```
packs/checklists/
  package.yml                       # namespace metadata, dependencies: ["."]
  README.md
  app/
    models/checklists/
      checklist.rb        -> Checklists::Checklist   self.table_name "checklists"
      section.rb          -> Checklists::Section      self.table_name "checklist_sections"
      item.rb             -> Checklists::Item         self.table_name "checklist_items"
    actions/checklists/
      create.rb update.rb delete.rb            -> Checklists::Create, ::Update, ::Delete
      create_item.rb toggle_item.rb            -> Checklists::CreateItem, ::ToggleItem
    policies/checklists/
      checklist_policy.rb -> Checklists::ChecklistPolicy
      item_policy.rb      -> Checklists::ItemPolicy
    subscribers/checklists/
      subscriber.rb       -> Checklists::Subscriber
    controllers/checklists/
      checklists_controller.rb         -> Checklists::ChecklistsController
      checklist_sections_controller.rb -> Checklists::ChecklistSectionsController
      checklist_items_controller.rb    -> Checklists::ChecklistItemsController
    components/checklists/
      card.rb form.rb item_row.rb      -> Checklists::Card, ::Form, ::ItemRow  (Phlex < Components::Base)
    views/checklists/
      index.rb show.rb new.rb edit.rb  -> Checklists::Index, ::Show, ::New, ::Edit  (Phlex)
    mcp/tools/checklists/
      create.rb update.rb delete.rb create_item.rb toggle_item.rb list.rb
                                       -> Checklists::Tools::Create … ::List
  spec/
    models/ actions/ policies/ requests/ system/ mcp/ factories/  (all checklist specs travel here)
```

**Why this resolves the Phlex autoloader hazard (G1):** the custom initializer
in `config/application.rb:43-53` only remaps the *root* `app/components` →
`Components::` and `app/views` → `Views::`. The pack's `app/components` and
`app/views` are registered by `packs-rails` as **standard root-namespace
autoload roots**, so plain Zeitwerk path-mapping applies:
`packs/checklists/app/components/checklists/card.rb → Checklists::Card`. No
custom remapping is needed for the pack; the two namespaces coexist.

---

## 2. Constant rename map (the single source of truth)

| Old (root, flat) | New (pack, namespaced) | File |
|---|---|---|
| `Checklist` | `Checklists::Checklist` | `models/checklists/checklist.rb` (+ `self.table_name "checklists"`) |
| `ChecklistSection` | `Checklists::Section` | `models/checklists/section.rb` (+ `self.table_name "checklist_sections"`) |
| `ChecklistItem` | `Checklists::Item` | `models/checklists/item.rb` (+ `self.table_name "checklist_items"`) |
| `Checklists::Create` *(action — already namespaced)* | `Checklists::Create` | `actions/checklists/create.rb` |
| `ChecklistItems::Create` / `::Toggle` | `Checklists::CreateItem` / `::ToggleItem` | `actions/checklists/*` |
| `ChecklistPolicy` | `Checklists::ChecklistPolicy` | `policies/checklists/checklist_policy.rb` |
| `ChecklistItemPolicy` | `Checklists::ItemPolicy` | `policies/checklists/item_policy.rb` |
| `ChecklistSubscriber` | `Checklists::Subscriber` | `subscribers/checklists/subscriber.rb` |
| `ChecklistsController` | `Checklists::ChecklistsController` | `controllers/checklists/checklists_controller.rb` |
| `ChecklistSectionsController` | `Checklists::ChecklistSectionsController` | `controllers/checklists/checklist_sections_controller.rb` |
| `ChecklistItemsController` | `Checklists::ChecklistItemsController` | `controllers/checklists/checklist_items_controller.rb` |
| `Components::ChecklistCard` | `Checklists::Card` | `components/checklists/card.rb` |
| `Components::ChecklistForm` | `Checklists::Form` | `components/checklists/form.rb` |
| `Components::ChecklistItemRow` | `Checklists::ItemRow` | `components/checklists/item_row.rb` |
| `Views::Checklists::{Index,Show,New,Edit}` | `Checklists::{Index,Show,New,Edit}` | `views/checklists/*.rb` |
| `Tools::{Create,Update,Delete}Checklist`, `Tools::{Create,Toggle}ChecklistItem`, `Tools::ListChecklists` | `Checklists::Tools::{Create,Update,Delete,CreateItem,ToggleItem,List}` | `mcp/tools/checklists/*.rb` |

> **Association names stay the same** (`trip.checklists`,
> `checklist.checklist_sections`, `section.checklist_items`) — only
> `class_name:` strings change. Route helpers (`trip_checklists_path`, …) and DB
> tables are **unchanged**.

---

## 3. External references to update (files that stay in root)

These are the *only* places outside the pack that name a Checklist constant:

1. **`app/models/trip.rb`** — `has_many :checklists` → add
   `class_name: "Checklists::Checklist"`.
2. **`app/models/audit_log/builder.rb`** (lines ~102, ~110) —
   `Checklist.find_by` → `Checklists::Checklist.find_by` (×2). Also the
   `auditable_type` written by `base` is `@entity.classify` → `"Checklist"`;
   add a small entity→class mapping so checklist rows store
   `"Checklists::Checklist"` (keeps `AuditLog#auditable` resolvable). Existing
   seed/dev rows are denormalised (feed renders from `summary`/`metadata`), so
   stale `"Checklist"` strings don't break the feed — note in PR, add a builder
   spec for the new type.
3. **`config/initializers/event_subscribers.rb`** —
   `ChecklistSubscriber.new` → `Checklists::Subscriber.new` (the
   `start_with?("checklist")` filter is unchanged — event names stay
   `checklist.*`).
4. **`app/mcp/trip_journal_server.rb`** — update the 6 tool constants in the
   registration array to `Checklists::Tools::*`.
5. **`config/routes.rb`** — wrap the checklist resources in `scope module: :checklists`
   so they route to the namespaced controllers without changing URLs:
   ```ruby
   resources :trips do
     scope module: :checklists do
       resources :checklists do
         resources :checklist_sections, only: %i[create destroy]
         resources :checklist_items, only: %i[create destroy] do
           # …existing member/collection routes…
         end
       end
     end
   end
   ```
6. **`db/seeds.rb`** (lines ~434-500) — `Checklist`/`ChecklistSection`/`ChecklistItem`
   → namespaced constants.
7. **Internal cross-refs inside the moved files** — controllers rendering
   `Views::Checklists::Index` → `Checklists::Index`; `Components::ChecklistForm`
   → `Checklists::Form`; views rendering `Components::ChecklistCard` →
   `Checklists::Card`; MCP tools' `Checklist.find` / `ChecklistSection.find` /
   `ChecklistItem.find` → namespaced; actions referencing the models.
8. **Specs & factories** — `describe Checklist` → `Checklists::Checklist`;
   `change(Checklist, :count)` → namespaced; `FactoryBot` factory names. Decide:
   keep factory names (`:checklist`, `:checklist_section`, `:checklist_item`)
   and only update their `class` if needed — FactoryBot infers class from name,
   so set `factory :checklist, class: "Checklists::Checklist"` explicitly.

> **Confirmed clean:** Checklist is **not** a `reactable` and **not** a
> `notifiable`, so there are no stored `reactable_type`/`notifiable_type`
> strings to migrate. The only stored type string is the audit `auditable_type`
> handled in (2).

---

## 4. ActionPolicy & FactoryBot resolution notes

- **ActionPolicy** derives the policy class from the record class:
  `Checklists::Checklist → Checklists::ChecklistPolicy`. Our layout matches, so
  `authorize!(@checklist)` and `allowed_to?(:show?, checklist)` resolve with no
  extra config. Verify `Checklists::ItemPolicy` is found for `Checklists::Item`
  (ActionPolicy looks for `Checklists::ItemPolicy`). If lookup misses, set
  `authorize!(item, with: Checklists::ItemPolicy)` explicitly.
- **FactoryBot**: set explicit `class:` on each factory after the rename;
  `packs-rails` auto-loads `packs/checklists/spec/factories`.

---

## 5. Packwerk configuration

`packs/checklists/package.yml`:
```yaml
enforce_dependencies: true     # flip on after baseline is green (Task T6)
enforce_privacy: false         # deferred — see roadmap
dependencies:
  - "."                        # root holds Trip, User, ApplicationRecord, Components::Base, MCP base, ActionPolicy base
metadata:
  owner: trip-journal
  namespace: Checklists
```

Root `package.yml` (created by `packwerk init`): `enforce_dependencies: false`,
`enforce_privacy: false` — so root code (audit builder, MCP server, Trip,
seeds) may reference `Checklists::*` freely. The pack may reference only what it
declares (`"."`).

---

## 6. Gotchas (carried from the foundation analysis, scoped to Checklist)

| # | Gotcha | Mitigation |
|---|--------|------------|
| G1 | Phlex `Components::`/`Views::` remapper | Solved by §1: pack components/views use standard root-namespace path-mapping; the remapper only touches root dirs. **Run `bin/rails zeitwerk:check` after the move.** |
| G2 | `rake project:tests` hardcodes `spec` | Add `--require packs/rails/rspec` to `.rspec`; widen task to `rspec spec packs --exclude-pattern "**/system/**"`. |
| G3 | Factories move with pack | `packs-rails` auto-loads `packs/*/spec/factories`; set explicit `class:`. |
| G4 | Prod eager-load | `RAILS_ENV=production bin/rails zeitwerk:check` after move. |
| G5 | Audit `auditable_type` string | §3.2 — map checklist entity to namespaced type; denormalised feed unaffected; add spec. |
| G6 | Namespaced controllers + routes | `scope module: :checklists` keeps URLs/helpers; verify each route resolves (`bin/rails routes | grep checklist`). |
| G7 | ActionPolicy lookup for `Checklists::Item` | Verify; fall back to explicit `with:` if needed. |
| G8 | RuboCop `Include` | Add `packs/**/*.rb` to `.rubocop.yml`; `rake project:fix-lint`. |
| G9 | CI `paths-ignore` | `packs/**` is runtime — must not be ignored; add `packwerk check` step to the runtime job. |

---

## 7. Ordered task list (atomic commits)

Per governance: GitHub issue first → Kanban → branch
`feature/phase-24-checklist-pack` → atomic commits → full validation + live
verification → PR. Run via `/execution-plan`.

- **T0** — Issue (label `refactor`), Kanban → *In Progress*, branch.
- **T1** — Add gems `packwerk`, `packs-rails`, `graphwerk` (dev/test); `bundle install`. *(chore deps)*
- **T2** — `packwerk init`; root `package.yml` (enforcement off); `packs.yml`; `.rspec` `--require`. `packwerk check` = 0 violations. *(chore packwerk baseline)*
- **T3** — `git mv` the full Checklist slice into `packs/checklists/...` (no renames yet); add `packs/checklists/package.yml` with `enforce_dependencies: false`. *(refactor: relocate checklist files)*
- **T4** — Apply the §2 namespace renames inside the pack (models + `self.table_name`, actions, policies, subscriber, controllers, components, views, MCP tools) and the §3 external updates (Trip, audit builder, event registry, MCP server, routes, seeds). `bin/rails zeitwerk:check` (dev + prod) green. *(refactor: namespace checklist under Checklists::)*
- **T5** — Update specs + factories (§3.8, §4). `rspec packs/checklists/spec` green; full `rake project:tests` green. *(test: move + namespace checklist specs)*
- **T6** — `packwerk update`; set `enforce_dependencies: true`; `packwerk check` green. *(chore packwerk: enforce checklist deps)*
- **T7** — `.rubocop.yml` include `packs/**`; `rake project:fix-lint` + `lint` green. Add `packwerk check` to `ci.yml` runtime job; confirm `packs/**` not in `paths-ignore`. Widen `project:tests` rake task (G2). *(chore lint + ci)*
- **T8** — `graphwerk update` (commit diagram); `packs/checklists/README.md` + root `CLAUDE.md`/`PROJECT SUMMARY.md` note; record outcome in `prompts/Phase 24 - Steps.md`. *(docs)*
- **T9** — Full validation gates (§8) + live verification (§9 of original; checklist flow + audit feed + MCP), then PR + review response.

---

## 8. Validation gates (executable)

```bash
mise x -- bundle install
mise x -- bin/rails zeitwerk:check
mise x -- env RAILS_ENV=production bin/rails zeitwerk:check
mise x -- bundle exec packwerk check                 # 0 violations
mise x -- bundle exec rake project:fix-lint
mise x -- bundle exec rake project:lint
mise x -- bundle exec rake project:tests             # root + pack specs
mise x -- bundle exec rake project:system-tests      # checklist system spec
mise x -- bundle exec graphwerk update && git diff --stat
```

Acceptance: all green; `packs/checklists/package.yml` has
`enforce_dependencies: true`; `package_todo.yml` has no entries (target: a clean
extraction needs none) or only documented, justified ones.

## 9. Live verification (mandatory before PR)

`/product-review`: `bin/cli app rebuild && app restart && mail start`, then via
`agent-browser`:
- [ ] Trip → Checklists: create checklist → add section → add item → toggle item (live) → edit → delete. All persist, no 500s.
- [ ] Activity feed still logs `checklist.*` events with correct summaries.
- [ ] MCP checklist tools operate (`/trip-journal-mcp` smoke: create/list/update/delete checklist, create/toggle item).
- [ ] Seeds load clean (`bin/cli db reset` in dev) with namespaced constants.

## 10. Deferred (roadmap)

Export, Onboarding, Trip, JournalEntry, Comment, Reaction, Notification,
ActivityFeed, Identity, MCP packs; `enforce_privacy` + the pack `public/` API;
component/view namespacing for the other domains. Each becomes its own phase
once the Checklist pack proves the pattern end-to-end.

## 11. Confidence

**8/10** for one-pass success. Checklist is the cleanest domain (single
`belongs_to :trip`, no polymorphic type strings), the rename map is fully
enumerated, and the Phlex-autoloader risk has a concrete solution. Residual
risk: ActionPolicy/namespaced-controller routing edge cases (G6/G7) and the
audit `auditable_type` mapping (G5) — each may need one iteration.
