# Checklists pack

A self-contained vertical slice for the **checklist** domain (checklists,
sections, items), namespaced under `Checklists::` and enforced by
[Packwerk](https://github.com/Shopify/packwerk). It is the first domain
extracted from the layered `app/` tree — treat it as a **pre-Rails-Engine**
unit: everything the domain needs lives here, and its boundary is machine-checked.

## Layout

```
packs/checklists/
  package.yml                    # dependencies + enforce_dependencies: true
  app/
    models/checklists/           Checklists::Checklist, ::Section, ::Item
    actions/checklists/          Checklists::Create, ::Update, ::Delete
    actions/checklists/items/    Checklists::Items::Create, ::Toggle
    policies/checklists/         Checklists::ChecklistPolicy, ::ItemPolicy
    subscribers/checklists/      Checklists::Subscriber
    controllers/checklists/      Checklists::ChecklistsController, ::ChecklistSectionsController, ::ChecklistItemsController
    components/checklists/       Checklists::Card, ::Form, ::ItemRow   (Phlex < Components::Base)
    views/checklists/            Checklists::Index, ::Show, ::New, ::Edit (Phlex < Views::Base)
    mcp/checklists/tools/        Checklists::Tools::Create … ::ToggleItem (< Tools::BaseTool)
  spec/                          specs + factories travel with the pack
```

## Dependency graph

```
Checklists  ──depends on──▶  .  (root package)
```

The pack depends **only** on the root package, which provides the shared
foundations it builds on: `ApplicationRecord`, `ApplicationPolicy`,
`ApplicationController`, `BaseAction`, `Components::Base`, `Views::Base`,
`Tools::BaseTool`, and the cross-domain models it references (`Trip`, `User`).
Nothing in the root package may reference `Checklists::*` through a declared
dependency — root keeps `enforce_dependencies: false`, so its references
(e.g. `Trip.has_many :checklists`) are allowed today and will be formalised
when more domains are extracted.

Run `bundle exec packwerk check` to verify boundaries. (A visual graph can be
produced with the `graphwerk` gem once the `graphviz`/`dot` binary is installed
and a `graphwerk:update` rake task is wired in — neither is set up here.)

## Conventions for this (and future) packs

- **One namespace per pack.** Every constant lives under `Checklists::`.
  Multiple autoload roots (`app/models`, `app/actions`, `app/views`, …) all
  contribute to the same module via Zeitwerk path mapping.
- **Preserve external contracts when namespacing.**
  - Models override `self.model_name` to keep the un-namespaced route/param
    keys (`checklist`, `checklists`), so routes, `form_with`, and
    `polymorphic_path` are unchanged.
  - DB tables are pinned with `self.table_name` — namespacing never triggers a
    migration.
  - MCP tools pin their public name with `tool_name "..."`, so the MCP API
    contract (`create_checklist`, `toggle_checklist_item`, …) is stable even
    though the class is `Checklists::Tools::Create`.
- **Controllers** are reached via `scope module: :checklists` in
  `config/routes.rb`, which keeps URLs and path helpers un-namespaced.
- **Pack views** are registered at the root namespace in
  `config/application.rb` (Rails/packs-rails do not autoload `app/views` by
  default; pack components are auto-registered by packs-rails).
- **Specs + factories** live under `packs/checklists/spec` and are discovered
  via `--require packs/rails/rspec` in `.rspec`.

## Events

The pack emits the same `Rails.event` names as before
(`checklist.created/updated/deleted`, `checklist_item.created/toggled`) — see
`Checklists::Subscriber` and the registry in
`config/initializers/event_subscribers.rb`. `AuditLog::Builder` maps these
events' `auditable_type` to the namespaced models.
