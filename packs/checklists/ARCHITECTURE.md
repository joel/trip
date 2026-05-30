# Checklists pack — architecture & Packwerk guide

Visual walkthrough of how **Packwerk** isolates the Checklist domain, how a
request flows through the pack, and a repeatable recipe for extracting the next
component. All diagrams are [Mermaid](https://mermaid.js.org/) — they render
inline on GitHub and can be pasted into <https://excalidraw.com> via
**Insert → Mermaid to Excalidraw** for free-form editing. An editable scene is
checked in at [`designs/phase-24-checklists-pack.excalidraw`](../../designs/phase-24-checklists-pack.excalidraw).

> New here? Read [`README.md`](README.md) first for the file layout; this doc is
> the "why and how it fits together".

---

## 1. TL;DR

The Checklist domain is a **self-contained vertical slice** under one namespace
(`Checklists::`) living in `packs/checklists/`. Packwerk machine-checks that the
pack only reaches what it declares. Today it declares exactly one dependency:
the root package.

```mermaid
flowchart LR
    subgraph pack["📦 packs/checklists  (Checklists::)"]
        direction TB
        M["models · actions · policies<br/>controllers · components · views<br/>subscribers · mcp · spec"]
    end
    subgraph root["📦 . — root package"]
        direction TB
        R["ApplicationRecord · ApplicationPolicy<br/>BaseAction · ApplicationController<br/>Components::Base · Views::Base<br/>Tools::BaseTool · Trip · User"]
    end
    pack -->|"dependencies: ['.']<br/>enforce_dependencies: true"| root
    classDef p fill:#dbeafe,stroke:#2563eb,color:#1e3a8a;
    classDef r fill:#f1f5f9,stroke:#64748b,color:#334155;
    class pack,M p
    class root,R r
```

**Reading the arrow:** "Checklists *depends on* root." The reverse is **not**
declared — root still references `Checklists::*` (e.g. `Trip has_many
:checklists`) only because root keeps `enforce_dependencies: false` for now.
When more domains are extracted those root→pack references get formalised.

---

## 2. Setup — what was installed & configured

```mermaid
flowchart TD
    G["Gemfile<br/>• packs-rails (runtime)<br/>• packwerk (dev/test)"]
    PW["packwerk.yml<br/>excludes lib/templates; cache on"]
    RP["package.yml (root)<br/>enforce_dependencies: false"]
    PP["packs/checklists/package.yml<br/>dependencies: ['.']<br/>enforce_dependencies: true"]
    RS[".rspec<br/>--require packs/rails/rspec"]
    APP["config/application.rb<br/>register packs/*/app/views<br/>at the root namespace"]
    RU[".rubocop.yml<br/>Phlex cops cover packs/*/app/{components,views}"]
    CI["CI + Rakefile<br/>packwerk check in project:lint<br/>specs run over spec + packs"]

    G --> PW --> RP --> PP
    G --> RS
    G --> APP
    PP --> RU
    PP --> CI

    classDef cfg fill:#fef9c3,stroke:#ca8a04,color:#713f12;
    class G,PW,RP,PP,RS,APP,RU,CI cfg
```

| File | Role |
|------|------|
| `Gemfile` | `packs-rails` (registers pack autoload/eager-load paths at boot); `packwerk` (the boundary checker) |
| `packwerk.yml` | global config — excludes `lib/templates/**` (ERB generator templates), enables cache |
| `package.yml` (root) | declares the root package; `enforce_dependencies: false` so root may reference packs during incremental adoption |
| `packs/checklists/package.yml` | the pack boundary: `dependencies: ['.']`, `enforce_dependencies: true` |
| `.rspec` | `--require packs/rails/rspec` so pack specs + factories are discovered |
| `config/application.rb` | registers each `packs/*/app/views` at the **root** namespace (Rails/packs-rails autoload pack *components* but not *views*) |
| `.rubocop.yml` | extends the Phlex cop exemptions to `packs/*/app/{components,views}` |
| CI / `Rakefile` | `packwerk check` runs in `project:lint` and CI; test tasks run over `spec` **and** `packs` |

---

## 3. Isolation — what Packwerk enforces

Packwerk checks every constant reference a file makes. A reference is **allowed**
only if the target lives in the same pack or in a pack listed under
`dependencies`.

```mermaid
flowchart TD
    A["A file in packs/checklists references a constant"] --> Q{"Where does the<br/>constant live?"}
    Q -->|"same pack (Checklists::*)"| OK1["✅ allowed"]
    Q -->|"root package (Trip, BaseAction…)"| D{"is '.' in<br/>dependencies?"}
    D -->|yes| OK2["✅ allowed"]
    D -->|no| V1["❌ dependency violation"]
    Q -->|"another pack not declared"| V2["❌ dependency violation<br/>(would need a new dependency)"]

    classDef ok fill:#dcfce7,stroke:#16a34a,color:#14532d;
    classDef bad fill:#fee2e2,stroke:#dc2626,color:#7f1d1d;
    classDef q fill:#e0e7ff,stroke:#4f46e5,color:#312e81;
    class OK1,OK2 ok
    class V1,V2 bad
    class Q,D q
```

- **Result today:** `bundle exec packwerk check` → **0 violations**, no
  `package_todo.yml` needed. The pack reaches only `Checklists::*` and root
  constants, and it declares root.
- **Privacy is deferred.** `enforce_privacy` (a `public/` API folder, via
  `packwerk-extensions`) is intentionally off for now — see the roadmap in
  [`prompts/Phase 24 Components Isolation.md`](../../prompts/Phase%2024%20Components%20Isolation.md).

---

## 4. Before → after: layered to pack

The domain used to be scattered across ten technical-layer directories. The
extraction gathered every layer into one namespaced slice — **no behaviour
changed**, tables and routes are identical.

```mermaid
flowchart LR
    subgraph before["BEFORE — by layer (root app/)"]
        direction TB
        b1["app/models/checklist.rb"]
        b2["app/actions/checklists/*"]
        b3["app/policies/checklist_policy.rb"]
        b4["app/controllers/checklists_controller.rb"]
        b5["app/components/checklist_card.rb"]
        b6["app/views/checklists/*"]
        b7["app/mcp/tools/*checklist*"]
        b8["spec/**/checklist*"]
    end
    subgraph after["AFTER — by domain (packs/checklists/)"]
        direction TB
        a1["app/models/checklists/{checklist,section,item}.rb"]
        a2["app/actions/checklists/… + items/…"]
        a3["app/policies/checklists/…"]
        a4["app/controllers/checklists/…"]
        a5["app/components/checklists/…"]
        a6["app/views/checklists/…"]
        a7["app/mcp/checklists/tools/…"]
        a8["spec/… (travels with the pack)"]
    end
    before ==>|"git mv + namespace under Checklists::"| after

    classDef b fill:#fee2e2,stroke:#dc2626,color:#7f1d1d;
    classDef a fill:#dcfce7,stroke:#16a34a,color:#14532d;
    class before,b1,b2,b3,b4,b5,b6,b7,b8 b
    class after,a1,a2,a3,a4,a5,a6,a7,a8 a
```

---

## 5. Constant ↔ autoload-path mapping

`packs-rails` registers each `packs/checklists/app/<layer>` as a Zeitwerk root,
so the **file path under the layer determines the constant** — all contributing
to one `Checklists::` namespace.

```mermaid
flowchart LR
    P1["app/models/checklists/checklist.rb"] --> C1["Checklists::Checklist"]
    P2["app/actions/checklists/items/toggle.rb"] --> C2["Checklists::Items::Toggle"]
    P3["app/controllers/checklists/checklists_controller.rb"] --> C3["Checklists::ChecklistsController"]
    P4["app/components/checklists/card.rb"] --> C4["Checklists::Card"]
    P5["app/views/checklists/index.rb"] --> C5["Checklists::Index"]
    P6["app/mcp/checklists/tools/create.rb"] --> C6["Checklists::Tools::Create"]

    classDef path fill:#f1f5f9,stroke:#64748b,color:#334155;
    classDef const fill:#dbeafe,stroke:#2563eb,color:#1e3a8a;
    class P1,P2,P3,P4,P5,P6 path
    class C1,C2,C3,C4,C5,C6 const
```

Three contracts are **preserved** so namespacing stays invisible to the rest of
the app:

| Concern | Technique | Effect |
|--------|-----------|--------|
| DB tables | `self.table_name = "checklists"` | no migration |
| Routes / forms | `self.model_name → "Checklist"` | `checklist`/`checklists` keys, "Create Checklist" button unchanged |
| MCP API | `tool_name "create_checklist"` | tool names stable despite `Checklists::Tools::Create` |
| Routing | `scope module: :checklists` in `routes.rb` | URLs & path helpers unchanged |

---

## 6. Flow design — a request through the pack

```mermaid
sequenceDiagram
    autonumber
    participant B as Browser
    participant R as Router (routes.rb)
    participant C as Checklists::ChecklistsController
    participant A as Checklists::Create (action)
    participant DB as Checklists::Checklist
    participant E as Rails.event
    participant S as Checklists::Subscriber
    participant AL as AuditLogSubscriber → AuditLog

    B->>R: POST /trips/:id/checklists
    R->>C: dispatch to Checklists::ChecklistsController#create
    C->>A: Checklists::Create.new.call(params:, trip:)
    A->>DB: trip.checklists.create!(...)
    A->>E: notify("checklist.created", checklist_id:, trip_id:)
    E-->>S: emit(event)  → logs
    E-->>AL: emit(event) → builds row (auditable_type: "Checklists::Checklist")
    A-->>C: Success(checklist)
    C-->>B: redirect → "Checklist created."
```

The same event bus powers the **live item toggle** (Turbo Stream) — note the
re-render uses the pack's own `Checklists::ItemRow` component:

```mermaid
sequenceDiagram
    autonumber
    participant B as Browser
    participant C as Checklists::ChecklistItemsController
    participant T as Checklists::Items::Toggle
    participant V as Checklists::ItemRow (Phlex)
    B->>C: PATCH …/checklist_items/:id/toggle (TURBO_STREAM)
    C->>T: call(checklist_item:)
    T->>T: item.toggle! + notify("checklist_item.toggled")
    C->>V: render_to_string(layout: false)
    C-->>B: turbo_stream.replace(dom_id(item), …)
```

**Why the event bus matters for isolation:** cross-domain reactions (audit feed,
notifications) subscribe to *string event names*, not pack constants — so the
pack stays decoupled from its consumers.

---

## 7. How-to: extract the next component

```mermaid
flowchart TD
    S1["1 · Inventory the slice<br/>models, actions, policies, controllers,<br/>components, views, mcp, specs, factories"] --> S2
    S2["2 · git mv into packs/&lt;domain&gt;/app/&lt;layer&gt;/&lt;domain&gt;/…"] --> S3
    S3["3 · Namespace under &lt;Domain&gt;::<br/>+ self.table_name + self.model_name<br/>+ tool_name + scope module:"] --> S4
    S4["4 · Update external refs<br/>associations (class_name:), audit builder,<br/>event registry, MCP server, seeds"] --> S5
    S5["5 · package.yml: dependencies: ['.']<br/>(start enforce_dependencies: false)"] --> S6
    S6{"bin/rails zeitwerk:check<br/>+ specs green?"}
    S6 -->|no| S3
    S6 -->|yes| S7["6 · packwerk update → enforce_dependencies: true → packwerk check"]
    S7 --> S8["7 · docs: README + ARCHITECTURE + this recipe"]

    classDef step fill:#dbeafe,stroke:#2563eb,color:#1e3a8a;
    classDef gate fill:#fef9c3,stroke:#ca8a04,color:#713f12;
    class S1,S2,S3,S4,S5,S7,S8 step
    class S6 gate
```

**Gotchas the Checklist extraction surfaced (apply them next time):**

1. Namespaced models change `ActiveModel::Name` → override `self.model_name`
   to keep route/param/form keys, and `self.table_name` to avoid a migration.
2. `packs-rails` autoloads pack **components** but **not views** — register
   `packs/*/app/views` at the root namespace in `config/application.rb`.
3. The `mcp` gem derives tool names from the class — pin `tool_name` to keep the
   public MCP contract.
4. `AuditLog::Builder` stores `auditable_type` from the event entity — add a
   namespaced-type override so the polymorphic type resolves.
5. After `db:reset`, **restart the app** (Puma holds the old SQLite handle).
6. Don't put `[skip ci]` in commit messages — CI is gated by `paths-ignore`.

---

## 8. Generating the dependency graph (graphwerk)

For a single pack the graph above is enough. Once several packs exist, generate
a real graph with [graphwerk](https://github.com/samuelgiles/graphwerk):

```ruby
# Gemfile (group :development, :test)
gem "graphwerk"
```
```ruby
# Rakefile
require "graphwerk/tasks" if defined?(Graphwerk)
```
```bash
# Needs the graphviz binary:
sudo apt-get install -y graphviz     # Debian/Ubuntu
bundle exec rake graphwerk:update    # writes packwerk.png
```

It was deliberately **not** kept as a dependency yet (a two-node graph isn't
worth the graphviz requirement) — re-add it when the graph earns its keep.

## 9. Editing the visuals in Excalidraw

Two ways to get an editable diagram at <https://excalidraw.com>:

1. **From Mermaid (recommended):** copy any ` ```mermaid ` block above →
   Excalidraw → **Insert → Mermaid to Excalidraw** → paste. You get fully
   editable shapes.
2. **Open the checked-in scene:** drag
   [`designs/phase-24-checklists-pack.excalidraw`](../../designs/phase-24-checklists-pack.excalidraw)
   onto the Excalidraw canvas (or **File → Open**).
