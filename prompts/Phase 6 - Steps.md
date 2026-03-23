# Phase 6 - Steps Taken

## 1. GitHub Issue Created
- Issue #27: "Phase 6: Export Architecture + Workflow Completion"
- Label: enhancement
- URL: https://github.com/joel/trip/issues/27

## 2. Feature Branch Created
- Branch: `feature/export-architecture`
- Base: `main`

## 3. Gems Added
- `reverse_markdown` — HTML-to-Markdown conversion for Action Text body
- `rubyzip` — ZIP packaging for Markdown export
- `gepub` was already in Gemfile

## 4. Migration Created
- `db/migrate/20260323100001_create_exports.rb`
- UUID PK, refs trip + user, format/status integer enums, timestamps
- Composite index on [trip_id, user_id, created_at]

## 5. Model Created
- `app/models/export.rb` — format enum (markdown/epub), status enum (pending/processing/completed/failed), has_one_attached :file

## 6. Policy Created
- `app/policies/export_policy.rb` — create: member + commentable, show/download: own or superadmin

## 7. Action Created
- `app/actions/exports/request_export.rb` — persist + emit `export.requested` event

## 8. Controller Created
- `app/controllers/exports_controller.rb` — index, new, create, show, download

## 9. Routes Updated
- Nested `resources :exports` under trips with `download` member route

## 10. Phlex Views Created
- `app/views/exports/index.rb` — list exports with status badges
- `app/views/exports/new.rb` — format selection (Markdown ZIP / ePub)
- `app/views/exports/show.rb` — export details + download link

## 11. Phlex Components Created
- `app/components/export_card.rb` — single export row with actions
- `app/components/export_status_badge.rb` — pending/processing/completed/failed badge

## 12. Services Created
- `app/services/exports/markdown_generator.rb` — Obsidian-compatible ZIP with YAML frontmatter
- `app/services/exports/html_to_markdown.rb` — reverse_markdown + Action Text attachment handling
- `app/services/exports/epub_generator.rb` — gepub-based ePub with XHTML chapters
- `app/services/exports/xhtml_wrapper.rb` — wraps HTML in valid XHTML document

## 13. Jobs Created
- `app/jobs/generate_export_job.rb` — ActiveJob::Continuable, 4 steps
- `app/jobs/process_journal_images_job.rb` — eager variant generation (800x600 + 200x200)
- `app/jobs/notify_trip_state_change_job.rb` — email all trip members on state change

## 14. Subscriber Created
- `app/subscribers/export_subscriber.rb` — dispatches GenerateExportJob on `export.requested`

## 15. Existing Subscribers Wired Up
- `JournalEntrySubscriber` — now dispatches ProcessJournalImagesJob
- `TripSubscriber` — now dispatches NotifyTripStateChangeJob

## 16. Mailers Created/Updated
- `app/mailers/export_mailer.rb` — export_ready notification
- `app/views/export_mailer/export_ready.text.erb` — email template
- `app/mailers/trip_mailer.rb` — added state_changed method
- `app/views/trip_mailer/state_changed.text.erb` — email template

## 17. Existing Files Modified
- `app/models/trip.rb` — added `has_many :exports`
- `app/models/user.rb` — added `has_many :exports`
- `config/routes.rb` — added exports resource nested under trips
- `config/initializers/event_subscribers.rb` — registered ExportSubscriber
- `app/views/trips/show.rb` — added "Exports" link
- `app/components/sidebar.rb` — added exports to active controller check
- `Gemfile` — added reverse_markdown, rubyzip

## 18. Specs Created
- `spec/factories/exports.rb`
- `spec/models/export_spec.rb`
- `spec/policies/export_policy_spec.rb`
- `spec/actions/exports/request_export_spec.rb`
- `spec/services/exports/markdown_generator_spec.rb`
- `spec/services/exports/epub_generator_spec.rb`
- `spec/jobs/generate_export_job_spec.rb`
- `spec/jobs/process_journal_images_job_spec.rb`
- `spec/jobs/notify_trip_state_change_job_spec.rb`
- `spec/requests/exports_spec.rb`

## 19. Test Results
- 371 examples, 0 failures, 2 pending (pre-existing)
- 13 system tests, 0 failures
- 0 lint offenses
