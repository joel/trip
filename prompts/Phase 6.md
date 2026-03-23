# Phase 6: Export Architecture + Workflow Completion

## Context

Phases 1-5 are complete (PRP Phases 1-6). This phase implements PRP Phase 7 (Eventing/Workflow — remaining items) and PRP Phase 10 (Export Architecture). The eventing infrastructure is mostly in place (21 events emitted, 9 subscribers registered), but 5 subscribers only log. The `gepub` gem is in the Gemfile but unused. `ActiveJob::Continuable` is confirmed available in Rails 8.1.2.

**Goal:** Add trip export functionality (Markdown ZIP + ePub) with async generation via Active Job Continuations, plus wire up remaining log-only subscribers to dispatch real jobs.

**Issue:** To be created on GitHub (joel/trip)

---

## Scope

### New: Export Architecture
- **Export model** — belongs_to trip + user, format enum (markdown/epub), status enum (pending/processing/completed/failed), has_one_attached :file
- **ExportPolicy** — any member can create on commentable trips, own exports only for show/download
- **Exports::RequestExport action** — persist + emit `export.requested`
- **ExportsController** — index, new, create, show, download
- **3 Phlex views** — index, new, show + 2 components (ExportCard, ExportStatusBadge)
- **MarkdownGenerator service** — Obsidian-compatible ZIP with YAML frontmatter, HTML-to-Markdown conversion, image extraction
- **EpubGenerator service** — gepub-based ePub with XHTML chapters and embedded images
- **GenerateExportJob** — Active Job Continuation (4 steps: mark_processing, generate_file, attach_file, notify_user)
- **ExportSubscriber** — dispatches GenerateExportJob on `export.requested`
- **ExportMailer** — notifies user when export is ready

### New: Workflow Wiring
- **JournalEntrySubscriber** — dispatch `ProcessJournalImagesJob` (eager variant generation)
- **TripSubscriber** — dispatch `NotifyTripStateChangeJob` (email all members on state change)
- **TripMailer#state_changed** — new mailer method + view

### New Gems
- `reverse_markdown` — HTML-to-Markdown conversion (Action Text body)
- `rubyzip` — ZIP packaging for Markdown export

---

## Permission Matrix

| Resource | Action | Superadmin | Contributor | Viewer | No Membership |
|----------|--------|-----------|-------------|--------|---------------|
| Export | create | yes | yes (member) | yes (member) | no |
| Export | show/download | yes | own only | own only | no |

Exports use `commentable?` — allowed on planning, started, and finished trips (not cancelled/archived).

---

## Files to Create (~31)

### Migration (1)
1. `db/migrate/TIMESTAMP_create_exports.rb` — uuid PK, refs trip + user, format/status integer enums, timestamps, index on [trip_id, user_id, created_at]

### Model (1)
2. `app/models/export.rb` — enums, belongs_to, has_one_attached :file, validates :format, scope :recent

### Policy (1)
3. `app/policies/export_policy.rb` — create?: member + commentable, show?/download?: own or superadmin

### Action (1)
4. `app/actions/exports/request_export.rb` — persist + emit `export.requested`

### Controller (1)
5. `app/controllers/exports_controller.rb` — index, new, create, show, download

### Views/Components (5)
6. `app/views/exports/index.rb` — list exports with status, download links
7. `app/views/exports/new.rb` — format radio buttons (Markdown / ePub)
8. `app/views/exports/show.rb` — export details, download link
9. `app/components/export_card.rb` — single export row
10. `app/components/export_status_badge.rb` — pending/processing/completed/failed badge

### Services (4)
11. `app/services/exports/markdown_generator.rb` — ZIP with _index.md, entry files, assets/
12. `app/services/exports/html_to_markdown.rb` — reverse_markdown wrapper, Action Text attachment handling
13. `app/services/exports/epub_generator.rb` — gepub-based ePub generation
14. `app/services/exports/xhtml_wrapper.rb` — wraps HTML in valid XHTML document

### Jobs (3)
15. `app/jobs/generate_export_job.rb` — ActiveJob::Continuable, 4 steps
16. `app/jobs/process_journal_images_job.rb` — eager variant generation (800x600 + 200x200)
17. `app/jobs/notify_trip_state_change_job.rb` — email all trip members

### Subscriber (1)
18. `app/subscribers/export_subscriber.rb` — dispatches GenerateExportJob

### Mailer + Views (3)
19. `app/mailers/export_mailer.rb` — export_ready notification
20. `app/views/export_mailer/export_ready.text.erb`
21. `app/views/trip_mailer/state_changed.text.erb`

### Specs (~10)
22. `spec/factories/exports.rb`
23. `spec/models/export_spec.rb`
24. `spec/policies/export_policy_spec.rb`
25. `spec/actions/exports/request_export_spec.rb`
26. `spec/services/exports/markdown_generator_spec.rb`
27. `spec/services/exports/epub_generator_spec.rb`
28. `spec/jobs/generate_export_job_spec.rb`
29. `spec/jobs/process_journal_images_job_spec.rb`
30. `spec/jobs/notify_trip_state_change_job_spec.rb`
31. `spec/requests/exports_spec.rb`

## Files to Modify (~10)

32. `app/models/trip.rb` — add has_many :exports
33. `app/models/user.rb` — add has_many :exports
34. `config/routes.rb` — add exports nested under trips
35. `config/initializers/event_subscribers.rb` — register ExportSubscriber
36. `app/subscribers/journal_entry_subscriber.rb` — dispatch ProcessJournalImagesJob
37. `app/subscribers/trip_subscriber.rb` — dispatch NotifyTripStateChangeJob
38. `app/mailers/trip_mailer.rb` — add state_changed method
39. `app/views/trips/show.rb` — add "Exports" link
40. `app/components/sidebar.rb` — add exports to active check
41. `Gemfile` — add reverse_markdown, rubyzip

---

## Key Design Decisions

1. **Generators as services** — `app/services/exports/` separates format-specific logic from the job orchestration. Each generator takes an Export record and returns a Tempfile.
2. **Active Job Continuations** — GenerateExportJob uses `include ActiveJob::Continuable` with 4 steps. Each step is independently restartable.
3. **Action Text attachments** — `<action-text-attachment>` tags need special handling: parse, extract blob, download image, replace with local path reference.
4. **ZIP for Markdown** — Obsidian-compatible directory structure packaged as ZIP via `rubyzip`.
5. **Export content excludes** comments, reactions, checklists, user data (per PRP).

## Risks

1. **ActiveJob::Continuable API** — `step :name` syntax needs verification. Confirmed module exists but exact step DSL should be tested. Fallback: standard job with manual status tracking.
2. **Action Text attachment parsing** — Trix embeds via `<action-text-attachment>` with signed blob references. Generator must extract and download actual images.
3. **Large exports** — Many images could cause memory pressure. Mitigate with streaming IO.

---

## Verification

### Automated Tests
```bash
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
mise x -- bundle exec rake project:lint
```

### Runtime Test Checklist
- [ ] Export request creates pending record + shows notice
- [ ] GenerateExportJob runs and produces file
- [ ] Markdown ZIP has correct structure (_index.md, entries, assets/)
- [ ] ePub is valid and readable
- [ ] Download link works for completed exports
- [ ] Email sent when export is ready
- [ ] Trip state change emails sent to members
- [ ] Image variants processed on journal entry creation
- [ ] Non-members denied, cancelled trips denied
- [ ] "Exports" button on trip show page

### Definition of Done
- [ ] Export model with migration, validations, enums
- [ ] ExportPolicy with full permission matrix
- [ ] Exports::RequestExport action with event emission
- [ ] ExportsController with 5 actions
- [ ] 3 Phlex views + 2 components
- [ ] MarkdownGenerator producing Obsidian-compatible ZIP
- [ ] EpubGenerator producing valid ePub
- [ ] GenerateExportJob with Active Job Continuations
- [ ] ExportMailer with export_ready notification
- [ ] ExportSubscriber dispatching GenerateExportJob
- [ ] JournalEntrySubscriber dispatching ProcessJournalImagesJob
- [ ] TripSubscriber dispatching NotifyTripStateChangeJob
- [ ] All existing tests still pass
- [ ] Runtime verification via agent-browser
