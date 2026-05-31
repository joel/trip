# Persistence safety (Phase 25)

Three complementary systems protect the critical, user-authored models —
`Trip`, `JournalEntry`, `Comment` — from accidental or malicious data loss.
Each answers a different question:

| System | Gem | The question it answers |
|--------|-----|-------------------------|
| **Soft delete** | `discard` | "It's gone — get it back." A deleted record is hidden, not destroyed, and can be restored with its whole child graph. |
| **Versioning** | `paper_trail` | "What did this say before — undo the edit." Every title/body edit is a revertible snapshot. |
| **AuditLog feed** | (Phase 21) | "Who did what — and the feed that surfaces Restore/Revert." The trip Activity feed renders the actions and the buttons to reverse them. |

> All diagrams below are [Mermaid](https://mermaid.js.org/) — they render inline
> on GitHub and can be pasted into <https://excalidraw.com> via
> **Insert → Mermaid to Excalidraw** for free-form editing.

---

## 1. Record lifecycle

A record is **Active** (kept) by default. `discard!` moves it to **Discarded**
(sets `discarded_at`, hidden by `default_scope { kept }`); `undiscard!` brings it
back. Editing a journal entry's title or body adds a `paper_trail` version
without changing the lifecycle state.

```mermaid
stateDiagram-v2
    [*] --> Active : create!
    Active --> Discarded : discard!  (sets discarded_at)
    Discarded --> Active : undiscard!  (parent-only)
    Active --> Active : update! (name/body) adds a paper_trail version

    note right of Active
        default_scope { kept }
        → discarded_at IS NULL
        Visible everywhere: views,
        MCP list_*, exports, counts,
        left_joins ON-clauses.
    end note

    note right of Discarded
        Hidden by the default scope.
        Only with_discarded sees it.
        Children cascade-discarded too:
          Trip → journal_entries → comments
        dependent: :destroy does NOT run,
        so the whole graph survives intact.
    end note
```

**Why the graph survives.** `discard` does not run validations and does not
trigger `dependent: :destroy`. A discarded trip keeps its memberships,
reactions, and attachments — that is precisely what lets a parent-only restore
recover everything beneath it.

**Cascade is down-only.** `Trip` has
`after_discard { journal_entries.kept.find_each(&:discard) }` and `JournalEntry`
has `after_discard { comments.kept.find_each(&:discard) }`. There is **no**
`after_undiscard` counterpart — restore is parent-only by design, so restoring a
trip does not auto-resurrect entries that were independently deleted first.

---

## 2. Delete → feed → restore

Deleting routes through the `*::Delete` action, which discards (cascading down)
and emits a `*.deleted` event. `AuditLogSubscriber` records it; the Activity feed
then offers a **Restore** button on that row, which calls the `*::Restore` action.

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant C as Controller
    participant D as *::Delete action
    participant M as Model (Trip/Entry/Comment)
    participant E as Rails.event
    participant AL as AuditLogSubscriber → AuditLog
    participant F as Activity feed (/trips/:id/activity)
    participant R as *::Restore action

    U->>C: DELETE the record
    C->>D: call(record:)
    D->>M: record.discard!  (sets discarded_at)
    M-->>M: after_discard → cascade children.kept.discard
    D->>E: notify("trip.deleted" / "journal_entry.deleted" / "comment.deleted")
    E-->>AL: emit(event) → Builder (with_discarded) → row
    Note over F: build_restorable maps auditable_id → discarded record<br/>only if parent chain kept AND restore? allows
    U->>F: open feed → sees "Restore" on the .deleted row
    F->>R: PATCH restore → call(record:)
    R->>M: record.undiscard!  (parent-only)
    R->>E: notify("*.restored") → forward audit event
```

### Revert (an edit, not a delete)

Each `*.updated` audit row carries its diff `{ field => [old, new] }` in
`metadata["changes"]`. The feed's **Revert** button re-applies the *old* values
through the record's normal Update action — so the revert is itself a forward
audit + version event, never a history edit.

```mermaid
flowchart LR
    A["*.updated audit row<br/>metadata['changes'] = { field => [old, new] }"]
    A --> B["Feed Revert button<br/>(build_revertable, keyed by audit_log id)"]
    B --> C["PATCH /trips/:id/activity/:id/revert"]
    C --> D["old_values = take the old of each [old, new] pair"]
    D --> E["record's Update action<br/>(Trips/JournalEntries/Comments::Update)"]
    E --> F["forward audit event + paper_trail version"]

    classDef step fill:#dbeafe,stroke:#2563eb,color:#1e3a8a;
    class A,B,C,D,E,F step
```

**Coverage.** Revert handles column fields — trip title/description/location/
dates and comment body. The journal-entry **rich-text body is not a column**, so
it never appears in the feed diff and is intentionally out of scope for Revert
(its history lives in `paper_trail` on `ActionText::RichText` instead).

### Where users reach these

- **Restore a deleted trip:** the trips index trash view — `/trips?discarded=1`
  ("Recently deleted"), superadmin-only, with a per-trip Restore button.
- **Restore a deleted entry/comment, or revert an edit:** the trip **Activity
  feed** (`/trips/:id/activity`) — a Restore button on `*.deleted` rows and a
  Revert button on `*.updated` rows, each shown only to users the policy allows.

Every button is authorised server-side (`restore?` / `update?`), not merely
hidden in the view.

---

## 3. Gotchas / rules

- **Delete now means discard.** No real `destroy` fires for `Trip`,
  `JournalEntry`, or `Comment`. `dependent: :destroy` only runs on an actual hard
  destroy, which the app no longer triggers for these models.
- **Use `with_discarded` everywhere you must see deleted rows** — restore paths,
  admin/trash views, and `AuditLog::Builder` subject finders. The default `kept`
  scope hides discarded rows from every other read path (this is the safety
  guarantee, not a bug).
- **`with_discarded.discarded`, never bare `.discarded`.** A bare `.discarded`
  self-contradicts `default_scope { kept }` (`discarded_at IS NULL AND IS NOT
  NULL` → always empty).
- **`paper_trail` requires the JSON serializer for `reify`.** Psych 4
  `safe_load` rejects `ActiveSupport::TimeWithZone`
  (`Psych::DisallowedClass`); JSON snapshots type-cast back cleanly.
- **The journal-entry body is versioned on `ActionText::RichText`, not on
  `journal_entries` columns.** Body edits therefore do not appear as
  Activity-feed column diffs.
- **`discard` skips validations and `dependent: :destroy`.** A discarded trip
  keeps its memberships, reactions, and attachments intact — that is what makes
  restore recover the whole graph.
- **Cascade is down-only.** Discarding a parent discards its kept children;
  restoring a parent does **not** re-discard or re-restore children. Restore is
  parent-only by design.

---

## 4. Where it lives

```
Models (include Discard::Model, default_scope { kept }, cascade after_discard)
  app/models/trip.rb                # + after_discard → journal_entries
  app/models/journal_entry.rb       # + after_discard → comments; has_paper_trail only: [:name]
  app/models/comment.rb

Actions
  app/actions/trips/delete.rb              # discard!
  app/actions/trips/restore.rb             # undiscard! + trip.restored
  app/actions/journal_entries/delete.rb    # discard!
  app/actions/journal_entries/restore.rb   # undiscard! + journal_entry.restored
  app/actions/comments/delete.rb           # discard!
  app/actions/comments/restore.rb          # undiscard! + comment.restored
  app/actions/journal_entries/create.rb    # PaperTrail.request(whodunnit:)
  app/actions/journal_entries/update.rb    # PaperTrail.request(whodunnit:)

Initializers
  config/initializers/paper_trail.rb              # JSON serializer (Psych 4 reify)
  config/initializers/paper_trail_action_text.rb  # versions the rich-text body

Migrations
  db/migrate/20260530100000_add_discarded_at_to_critical_models.rb  # discarded_at + index
  db/migrate/20260530153128_create_versions.rb                      # UUID-corrected versions table
  db/migrate/20260530153129_add_object_changes_to_versions.rb       # object_changes diff column

Feed integration (Phase 21 AuditLog)
  app/models/audit_log/builder.rb           # subject finders use with_discarded
  app/controllers/audit_logs_controller.rb  # build_restorable / build_revertable / #revert
  app/controllers/trips_controller.rb       # ?discarded=1 trash view + #restore
  app/components/audit_log_card.rb          # Restore + Revert buttons

Policies (restore? mirrors destroy?)
  app/policies/trip_policy.rb
  app/policies/journal_entry_policy.rb
  app/policies/comment_policy.rb

Routes (config/routes.rb)
  PATCH /trips/:id/restore
  PATCH /trips/:trip_id/journal_entries/:id/restore
  PATCH /trips/:trip_id/journal_entries/:journal_entry_id/comments/:id/restore
  PATCH /trips/:trip_id/activity/:id/revert
```

---

See the [Audit Journal (Phase 21)](../AGENTS.md) section in the root `AGENTS.md`
for the underlying event-capture pipeline this feature builds on.
