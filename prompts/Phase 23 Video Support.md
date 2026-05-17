# PRP: Phase 23 — Video Support (Ingestion · Optimization · Playback)

**Status:** Draft — **§1 Q1–Q5 resolved 2026-05-17**. Scope expanded by the Q3 decision to add an S3-compatible store (SeaweedFS, issue #44) + Active Storage **Direct Upload**. **Do not start coding. Await approval of the revised scope & sequencing.**
**Date:** 2026-05-17 (revised)
**Type:** Feature — new media type end-to-end: model + migration, async ffmpeg pipeline, 2 MCP tools, Phlex player + Stimulus, Phase-22 lightbox/gallery unification — **plus** an infra/storage track: ffmpeg in Dockerfile+CI, **SeaweedFS as the Active Storage service (#44)**, and browser→storage **Direct Upload**.
**Confidence Score:** **5/10 as one combined phase** (down from 6 — the Q3 decision pulls issue #44 + Direct Upload, an importmap/no-npm client-upload flow, into scope). **≈7/10 if split** into a prerequisite track **23a** (SeaweedFS/#44 + Active Storage Direct Upload) delivered first, then **23b** (video model/pipeline/player/unified lightbox) built on it — **strongly recommended** (see [§5.0](#50-storage-backend--direct-upload-q3--depends-on-44) and [§13](#13-task-list-ordered)). The video half still has ~70% exact in-repo precedent (image pipeline 1:1, `Export` async-model, Phase 22 surfaces, the `#145 Install libvips in CI` infra precedent). The risk concentrates in: (1) **ffmpeg in Dockerfile + CI** (exact Phase 22 libvips failure mode if missed); (2) the **SeaweedFS service + Direct Upload** track, which is net-new infra with no in-repo precedent and the `@rails/activestorage` JS conflicts with the no-npm/importmap rule; (3) resilient ffmpeg transcode/poster/probe shell-outs; (4) the unified-media **lightbox rendering `<video>` as well as `<img>`** (extends the Phase 22 contract); (5) connection-aware / reduced-motion / IntersectionObserver autoplay JS (no in-repo precedent).

---

## Table of Contents

1. [Clarifying Questions — Proposed (Confirm Before Coding)](#1-clarifying-questions--proposed-confirm-before-coding)
2. [Problem Statement](#2-problem-statement)
3. [Goals and Non-Goals](#3-goals-and-non-goals)
4. [Codebase Context (exact precedents)](#4-codebase-context-exact-precedents)
5. [Architecture & Key Decisions](#5-architecture--key-decisions)
6. [Data Model & Migration](#6-data-model--migration)
7. [Ingestion](#7-ingestion)
8. [Optimization Pipeline](#8-optimization-pipeline)
9. [Playback & UX](#9-playback--ux)
10. [Accessibility & Data-Respect Requirements](#10-accessibility--data-respect-requirements)
11. [Edge Cases](#11-edge-cases)
12. [Implementation Blueprint](#12-implementation-blueprint)
13. [Task List (ordered)](#13-task-list-ordered)
14. [Testing Strategy](#14-testing-strategy)
15. [Validation Gates (Executable)](#15-validation-gates-executable)
16. [Runtime Test Checklist](#16-runtime-test-checklist)
17. [Google Stitch Plan](#17-google-stitch-plan)
18. [Documentation Updates](#18-documentation-updates)
19. [Rollback Plan](#19-rollback-plan)
20. [Out of Scope / Future Phase](#20-out-of-scope--future-phase)
21. [Reference Documentation](#21-reference-documentation)
22. [Quality Checklist](#22-quality-checklist)

---

## 1. Clarifying Questions — RESOLVED (2026-05-17)

All five resolved by the product owner. The PRP body reflects the **Resolution** column. Two carry scope additions beyond the original options (Q2 → tracking issue; Q3 → SeaweedFS + Direct Upload).

| # | Question | **Resolution** | Consequence |
|---|----------|----------------|-------------|
| Q1 | Attachment modelling? | ✅ **Dedicated `JournalEntryVideo` model** (UUID pk, `belongs_to :journal_entry`, `has_one_attached :source`/`:web`/`:poster`, columns `status`/`duration`/`width`/`height`/`position`). | Enables the "optimizing…" processing state, poster↔source↔rendition correlation, and player dimensions. Mirrors the `Export` async-model precedent. See [§6](#6-data-model--migration). |
| Q2 | Transcoding scope? | ✅ **Option A — one normalized rendition (≤720p H.264+AAC `+faststart`) + poster.** **[Issue #147](https://github.com/joel/trip/issues/147)** opened to track Options B (ladder) & C (HLS) as deferred improvements, to be picked up *only if* Option A proves insufficient (buffering on poor connections / device mismatch / longer clips). | Single deterministic ffmpeg command — testable, one-pass-safe. Model designed so #147 needs no migration rewrite. |
| Q3 | Ingestion paths, ceilings & storage? | ✅ **URL-primary + base64 parity, limits ≤200 MB / ≤3 min / ≤5 per entry / `video/mp4,quicktime,webm`** — **AND** introduce an S3-compatible store (**SeaweedFS, issue #44**) with Active Storage **Direct Upload** so the browser sends raw bytes straight to the store and hands the server a blob handle (no 200 MB through a Rails request). | **Scope expansion.** Pulls #44 forward and adds a browser direct-upload flow. Recommended sequencing: prerequisite track **23a** (SeaweedFS + Direct Upload) → **23b** (video). See [§5.0](#50-storage-backend--direct-upload-q3--depends-on-44). |
| Q4 | Human web-form upload of video? | ✅ **Yes** — `JournalEntryForm` gains a video field; with Q3's Direct Upload the browser uploads straight to SeaweedFS (the 200 MB ceiling becomes viable; no Rack body-limit problem). | The form path and the Direct Upload track converge — Q4 is the main consumer of Q3's direct upload. |
| Q5 | Lightbox/gallery unification depth? | ✅ **Option A — full unified media lightbox.** Phase 22 overlay renders `<video controls playsinline>` for video items, `<img>` for images; gallery interleaves video poster + ▶ tiles in the one flat grid. | Highest one-pass risk in the video half (extends the Phase 22 controller/overlay contract). Accepted; flagged as the item most likely to need a polish pass. |

---

## 2. Problem Statement

Phase 22 made **images** first-class: lightbox, trip gallery, variant thumbnails. A trip journal still cannot hold the thing that most captures a moment — **video** (motion, sound, atmosphere). Today `JournalEntry` has only `has_many_attached :images`; there is no video association, no ingestion path (MCP or web), no transcoding, no player, and the Phase 22 gallery/lightbox are image-only.

Raw phone/camera video is large and inconsistently encoded (HEVC/.mov from iPhone, VP9/WebM, oversized bitrates). Serving originals directly is slow, often unplayable cross-browser, and burns mobile data. The app needs **ingestion** (validated, agent-driven, like images), **optimization** (async transcode + poster, off the request/agent path), and **playback** (effortless, polite: muted autoplay only where allowed, `playsinline`, IntersectionObserver play/pause, poster-first, `prefers-reduced-motion` and Save-Data aware), with video sitting **alongside images in one unified media view** in the Phase 22 gallery and entry cards.

---

## 3. Goals and Non-Goals

### Goals
1. **Ingestion** — agents attach videos exactly like images: `add_journal_videos` (HTTPS URLs, SSRF-safe) and `upload_journal_videos` (base64), plus the human form. Format/size/**duration** validated at upload; common phone/camera formats accepted.
2. **Optimization** — an **asynchronous** pipeline transcodes each upload to one web-friendly rendition (≤720p H.264+AAC, faststart), extracts a poster frame, records duration/dimensions, and tracks status — never blocking the upload, the agent, or the request.
3. **Playback** — a reusable `Components::VideoPlayer` + Stimulus controller: poster-first, `preload` sensible, `playsinline`, muted autoplay **only where the browser permits**, IntersectionObserver play-in-view/pause-out, format fallback, and **respecting `prefers-reduced-motion` and Save-Data / connection-aware** loading.
4. **Unified media view** — video slots into the Phase 22 trip gallery and entry cards beside images (poster tile + ▶ badge; plays in the unified lightbox).
5. **Infra** — `ffmpeg`/`ffprobe` available in the app image and CI so the pipeline and tests actually run.

### Non-Goals (see [§20](#20-out-of-scope--future-phase))
- HLS / adaptive bitrate ladder / DASH (brief says "*consider*" — future).
- Client-side recording, trimming, in-app editing, thumbnails-scrubbing.
- Live streaming, captions/subtitles ingestion, audio-only media.
- Per-rendition CDN tuning / SeaweedFS migration (#44 is separate; note storage growth).
- Reactions/comments semantics changes; video does not change the entry/comment model beyond the new association.

---

## 4. Codebase Context (exact precedents)

Read these before implementing — each video piece copies an image sibling.

| Concern | Precedent file(s) | What to mirror |
|---|---|---|
| URL ingestion + SSRF hardening | `app/actions/journal_entries/attach_images.rb` | The pinned-DNS / blocked-network / redirect-revalidation machinery is **security-critical — copy verbatim**, only swapping content-type allowlist, size, and the count guard. |
| Base64 ingestion | `app/actions/journal_entries/upload_images.rb` | `normalize_*`, `decode_one`, Marcel content-type-from-bytes, `MAX_ENCODED_SIZE`, transactional attach. |
| Action conventions | `app/actions/base_action.rb`, `app/actions/CLAUDE.md` | `BaseAction` (`Dry::Monads[:result,:do]`), `yield` railway, persist → emit event → `Success`. |
| Event → subscriber → job | `journal_entry.images_added` in both actions; `app/subscribers/journal_entry_subscriber.rb`; `app/jobs/process_journal_images_job.rb`; `config/initializers/event_subscribers.rb` | Add `journal_entry.videos_added`; extend the subscriber `case`; new `ProcessJournalVideosJob`; the `JournalEntrySubscriber` is already registered for `journal_entry.*`. |
| Async-processed model w/ Active Storage + status | `Export` model + `GenerateExportJob` (`app/jobs/generate_export_job.rb`) | The template for `JournalEntryVideo`: a record whose heavy artefact is produced async and whose `status` gates the UI. |
| MCP tools | `app/mcp/tools/add_journal_images.rb`, `upload_journal_images.rb`, `base_tool.rb`; registry `app/mcp/trip_journal_server.rb`; docs `app/mcp/README.md` | `add_journal_videos` / `upload_journal_videos` are near-verbatim; **must be added to `TripJournalServer::TOOLS`** and the server instructions string. |
| Audit mapping | `app/models/audit_log/builder.rb` (`"images_added" => "added images to"`) | Add `"videos_added" => "added videos to"`. |
| Entry card media render | `app/components/journal_entry_card.rb` (+ `journal_entry_card/image_lightbox.rb`) | Cover/grid render + the `lightbox` controller wiring on the `<article>` — extend to include video items. |
| Lightbox / gallery (Phase 22) | `app/components/lightbox.rb`, `lightbox_overlay.rb`, `app/javascript/controllers/lightbox_controller.js`, `app/views/trips/gallery.rb`, `app/controllers/trips_controller.rb#gallery` | The unified media view extends these. Note the **portal-to-`<body>` + `turbo:before-cache`** machinery and the `data-lightbox-*` contract — video support must preserve both. |
| Web form | `app/components/journal_entry_form.rb` (`form.file_field :images … accept:"image/*"`); `journal_entries_controller.rb#journal_entry_params` (`{ images: [] }`) | Add `videos` field + permit `{ videos: [] }`. |
| Infra precedent | Phase 22 commit `#145 Install libvips in CI` (`.github/workflows/ci.yml`), `Dockerfile` line ~20 (`apt-get install … libvips …`) | **Add `ffmpeg` to the same Dockerfile apt line and a CI step**, identical pattern. |
| Test patterns | `spec/actions/journal_entries/{attach,upload}_images_spec.rb`, `spec/requests/mcp_spec.rb`, `spec/system/trip_gallery_spec.rb`, `spec/factories/journal_entries.rb` (`:with_images` trait builds a real blob) | A `:with_video` factory trait + action/request/system specs mirror these. CI runs non-`:js` system specs under **rack_test**, `:js` under `selenium_chrome_headless` (`spec/support/system_test.rb`) — video playback specs must be `:js`. |

### Image-pipeline shape to clone (verified)

```
Agent → Tools::AddJournalImages / UploadJournalImages
      → JournalEntries::AttachImages / UploadImages   (validate → attach → emit)
      → Rails.event "journal_entry.images_added"
      → JournalEntrySubscriber#emit  → ProcessJournalImagesJob.perform_later
      → (job) variant().processed                     (off request path)
Render: JournalEntryCard cover/grid + Phase22 Lightbox/Gallery (image-only today)
```

---

## 5. Architecture & Key Decisions

### 5.0 Storage backend & Direct Upload (Q3 — depends on #44)

The Q3 decision adds an infra/storage track that **must land before video ingestion is usable**, because pushing a 200 MB upload through a Rails request is exactly the problem this solves.

- **SeaweedFS as the Active Storage service (= issue [#44](https://github.com/joel/trip/issues/44)).** `config/storage.yml` already has a working `seaweedfs:` S3-compatible stanza (endpoint/keys/bucket via ENV) — it is configured but **not run or selected**. The track must: stand up a SeaweedFS service in the project's container orchestration (alongside the existing mail service; mechanism = `bin/cli`/Compose — confirm during 23a), point `config.active_storage.service` at `:seaweedfs` for the relevant envs, create the bucket, and verify round-trip attach/serve. This is the substance of #44 — **Phase 23 pulls #44 forward; do not duplicate it, deliver #44 as track 23a and reference it.**
- **Active Storage Direct Upload (browser → SeaweedFS).** Built-in Rails flow: client requests a signed URL from `POST /rails/active_storage/direct_uploads`, `PUT`s the bytes straight to SeaweedFS (S3 presigned), then submits the returned **`signed_id`** with the form; the server attaches by `signed_id` and the bytes never transit a Rails request. **Constraint:** the canonical client is `@rails/activestorage` JS — the repo is **importmap-only, no npm** (PROJECT SUMMARY). Two viable paths, decide in 23a:
  - **✅ DECIDED (2026-05-17): path (a) — `bin/importmap pin @rails/activestorage`** (CDN pin, consistent with the Phase 22 "PhotoSwipe via importmap CDN" precedent), wired through a tiny Stimulus controller. The hand-rolled-uploader alternative is dropped.
- **Sequencing — ✅ DECIDED (2026-05-17): SPLIT.** Delivery is two independent phases: **Track 23a** = SeaweedFS (#44) + Direct Upload (`@rails/activestorage` pinned) + a smoke test (large image via direct upload round-trips to SeaweedFS) — its own issue/branch/PR/release `phase-23a`. **Track 23b** = the video model/pipeline/player/unified lightbox, building on 23a, release `phase-23b`. 23a ships and is verified before 23b begins.
- **Agent paths are unaffected by Direct Upload.** The MCP `add_journal_videos` (URL) path already streams server-side from the URL to a tempfile, and `upload_journal_videos` (base64) is small-clip only — neither needs the browser direct-upload flow. Direct Upload is the **human web-form** large-file path (Q4). All paths ultimately produce a `JournalEntryVideo` with `source` attached **to SeaweedFS** once 23a lands.

### 5.1 Video feature decisions

1. **Dedicated `JournalEntryVideo` model (Q1).** A first-class media type with lifecycle. `belongs_to :journal_entry`; `has_one_attached :source` (the upload), `has_one_attached :web` (normalized rendition), `has_one_attached :poster`; columns: `status` (enum `pending|processing|ready|failed`), `duration` (float, seconds), `width`, `height`, `position` (integer for ordering), `error_message` (text, nullable). All UUID PKs (project convention). `JournalEntry has_many :videos, -> { order(:position) }, class_name: "JournalEntryVideo", dependent: :destroy`.
2. **Ingestion mirrors images, returns immediately.** `JournalEntries::AttachVideos` / `UploadVideos` validate (content-type, size, **duration via ffprobe on the staged tempfile**, count), create `JournalEntryVideo` rows with `source` attached + `status: :pending`, emit `journal_entry.videos_added`, return `Success`. No transcoding inline.
3. **Async optimization.** `JournalEntrySubscriber` routes `journal_entry.videos_added` → `ProcessJournalVideosJob.perform_later(journal_entry_id)`. The job, per `pending` video: set `processing`; shell out to **ffmpeg** to produce the ≤720p H.264+AAC `+faststart` MP4 and a poster JPEG; probe dimensions/duration via **ffprobe**; attach `web` + `poster`; set `ready` (or `failed` + `error_message`). **Idempotent** (skip non-`pending`), never raises out (rescue → `failed`, log) so a bad video never breaks the feed — mirrors `ProcessJournalImagesJob` resilience and the Phase 22 "never 500 the page" rule.
4. **ffmpeg via controlled shell-out**, not a gem, by default (zero new dependency, deterministic args). `streamio-ffmpeg` is the optional fallback if probing/escaping proves fiddly — flagged, not assumed. Commands run with explicit arg arrays (no shell interpolation) and a timeout.
5. **Playback = `Components::VideoPlayer` + `video_player_controller.js`.** Poster-first `<video playsinline preload="metadata">` with `<source>` (web rendition) and graceful fallback to source if `ready` but rendition missing, or a "still optimizing" poster placeholder while `pending|processing`. The Stimulus controller owns autoplay/visibility/politeness (see §9–§10). No npm — importmap Stimulus only.
6. **Unified media in the Phase 22 surfaces (Q5).** Generalise the lightbox data contract from "images" to **media items** `{ kind: "image"|"video", thumb_url, full_url|sources, poster_url, caption }`. `Components::Lightbox` + `LightboxOverlay` + `lightbox_controller.js` render `<img>` or `<video>` by `kind`. `Views::Trips::Gallery` and `JournalEntryCard` build a merged, ordered media list (images + ready videos; processing videos show a poster/placeholder tile, not a broken slide).
7. **Infra is a first-class task, not an afterthought.** ffmpeg+ffprobe into `Dockerfile` (same apt line as libvips) **and** a CI step (mirroring `#145`). Without it: ingest duration-probe fails, the job fails, and `:js` system specs that render a poster/`<video>` surface server errors via Capybara — the exact Phase 22 libvips failure mode. This task ships **first** and is verified before feature code.

### Why these decisions
- **Model over `has_many_attached`:** playback fundamentally needs a *state* ("optimizing…") and correlated poster/rendition; the brief calls video "a first-class media type". `Export` proves the async-model pattern is idiomatic here.
- **Single rendition (Q2):** one deterministic ffmpeg invocation is unit-testable and CI-stable; a ladder/HLS is a multiplicative risk the brief only asked us to "consider".
- **Shell-out over gem:** no new dependency, full control of args/faststart; matches the project's lean dependency posture.
- **Generalise, don't fork, the lightbox:** a parallel video lightbox would duplicate the Phase 22 portal/Turbo-cache/focus-trap machinery (and its bug history). One contract, two element types.

---

## 6. Data Model & Migration

```ruby
# db/migrate/XXXXXXXX_create_journal_entry_videos.rb
create_table :journal_entry_videos, id: :uuid do |t|
  t.references :journal_entry, type: :uuid, null: false, foreign_key: true, index: true
  t.integer :status, null: false, default: 0          # enum pending/processing/ready/failed
  t.float   :duration                                  # seconds (ffprobe)
  t.integer :width
  t.integer :height
  t.integer :position, null: false, default: 0
  t.text    :error_message
  t.timestamps
end
add_index :journal_entry_videos, [:journal_entry_id, :position]
```

```ruby
class JournalEntryVideo < ApplicationRecord
  belongs_to :journal_entry
  has_one_attached :source
  has_one_attached :web
  has_one_attached :poster
  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }, default: :pending
  scope :ready, -> { where(status: :ready) }
end

# JournalEntry
has_many :videos, -> { order(:position) },
         class_name: "JournalEntryVideo", dependent: :destroy
```

`db/schema.rb` is regenerated; `RailsSchemaUpToDate` overcommit hook must pass (run migration before committing the model). UUID PK + `type: :uuid` FK is mandatory (project convention; see existing `active_storage_*` tables all `id: uuid`).

---

## 7. Ingestion

**`JournalEntries::AttachVideos`** (clone `AttachImages`):
- `ALLOWED_CONTENT_TYPES = %w[video/mp4 video/quicktime video/webm]` (Q3 — covers iPhone `.mov`, Android/desktop `.mp4`, WebM; transcode normalizes the rest anyway).
- `MAX_FILE_SIZE = 200.megabytes`, `MAX_VIDEOS_PER_ENTRY = 5`, `MAX_URLS_PER_CALL = 3`, `MAX_DURATION = 180` (seconds).
- **Reuse the entire SSRF stack verbatim** (`BLOCKED_NETWORKS`, `resolve_and_validate!`, `fetch_with_pinned_ip`, redirect re-validation). Streaming download to a Tempfile (not `StringIO`) — 200 MB in memory is unacceptable; cap bytes read at `MAX_FILE_SIZE`, abort if exceeded.
- After download: **`ffprobe` the tempfile** for duration/dimensions; `Failure` if duration > `MAX_DURATION` or unprobeable. Create `JournalEntryVideo(status: :pending, position:)`, `video.source.attach(io:…)`, emit `journal_entry.videos_added` (payload `journal_entry_id`, `trip_id`, `count`).

**`JournalEntries::UploadVideos`** (clone `UploadImages`): base64 path, same validations, **much smaller practical ceiling** (document that base64 is for short clips; URL is primary). Marcel content-type from bytes; ffprobe the decoded tempfile.

**MCP tools** `Tools::AddJournalVideos` / `Tools::UploadJournalVideos` (clone the image tools): add to `TripJournalServer::TOOLS` **and** extend the `instructions_for` string ("attach images and videos via URL or base64…"). Update `app/mcp/README.md`.

**Web form (Q4 + Q3 Direct Upload)**: `journal_entry_form.rb` gains a video field that uses **Active Storage Direct Upload** — the browser uploads bytes straight to SeaweedFS and submits the resulting `signed_id`(s); the controller permits `{ videos: [] }` and the create/update path attaches by `signed_id`, creating `JournalEntryVideo(status: :pending)` rows (no `UploadVideos` base64 decode for the form path; the bytes never hit a Rails request). Because of Direct Upload there is **no Rack/proxy body-size problem** for the 200 MB ceiling — this supersedes the earlier "Rack body-limit ops item". Requires track 23a (SeaweedFS + Direct Upload client) in place; until then the form video field is non-functional and must not ship.

Gotcha: bang methods + `docker exec … rails runner` (project rule) — use heredoc in any runtime scripts.

---

## 8. Optimization Pipeline

`app/jobs/process_journal_videos_job.rb` (mirror `ProcessJournalImagesJob` + `GenerateExportJob`):

```
perform(journal_entry_id):
  entry = JournalEntry.find_by(id: journal_entry_id) ; return unless entry
  entry.videos.where(status: :pending).find_each do |v|
    v.processing!
    Dir.mktmpdir do |dir|
      src = download blob to dir
      probe = ffprobe(src)  -> duration,width,height
      web    = ffmpeg transcode → ≤720p H.264 + AAC, -movflags +faststart, yuv420p
      poster = ffmpeg -ss 1 -frames:v 1 (or video.preview) → JPEG
      v.web.attach(web) ; v.poster.attach(poster)
      v.update!(duration:, width:, height:, status: :ready)
    end
  rescue => e
    v.update(status: :failed, error_message: e.message.truncate(500))
    Rails.logger.error(...)   # never re-raise — a bad video must not break the feed
  end
```

ffmpeg args (deterministic, arg-array, no shell): `-y -i SRC -vf "scale='min(1280,iw)':-2" -c:v libx264 -profile:v main -preset veryfast -crf 23 -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart OUT.mp4`. Poster: `-y -ss 00:00:01 -i SRC -frames:v 1 -q:v 3 OUT.jpg` (fallback `-ss 0` for clips < 1s). Wrap each ffmpeg/ffprobe call with a timeout and check exit status; treat non-zero as a `failed` video, not a job crash.

Idempotency: only `pending` processed; re-enqueue safe. Storage note: source+web+poster ≈ 2–3× original; flag for #44/SeaweedFS capacity. Solid Queue: long job — acceptable (off request path); ensure not on a latency-sensitive queue (use `:default` like the image job, or a dedicated `:media` queue if the owner prefers — minor).

---

## 9. Playback & UX

`Components::VideoPlayer.new(video:)` renders by `video.status`:
- `ready`: `video(playsinline:, preload:"metadata", poster: poster_url, controls:, muted:, loop: false, data:{controller:"video-player", ...})` with `source(src: web_url, type:"video/mp4")` and a graceful `source` fallback to the original if web missing.
- `pending|processing`: a poster/placeholder tile with an "Optimizing video…" affordance (no broken `<video>`); the card/gallery still renders.
- `failed`: a small non-blocking "Video unavailable" placeholder.

`video_player_controller.js` (Stimulus, importmap-only — pattern mirrors `lightbox_controller.js`/`feed_entry_controller.js`):
- **IntersectionObserver**: when ≥ ~50% visible → `play()` (muted), when out → `pause()`. Disconnect observer in `disconnect()` (Turbo-safe, like the lightbox `before-cache` discipline).
- **Autoplay policy**: only attempt muted autoplay; honour the returned `play()` promise rejection (browser blocked) → fall back to poster + tap-to-play. Always `muted` + `playsinline` for autoplay to be permitted (MDN autoplay guide).
- **Reduced motion**: `window.matchMedia("(prefers-reduced-motion: reduce)")` → never autoplay; poster + explicit control only.
- **Save-Data / connection-aware**: `navigator.connection?.saveData` or `effectiveType` in `slow-2g|2g` → `preload="none"`, no autoplay, tap-to-load.
- Pause others when one plays (optional, nice-to-have).

**Unified lightbox/gallery (Q5):** generalise the Phase 22 contract. `Components::Lightbox` items become `{ kind:, thumb_url:, src:, poster_url:, caption: }`. `LightboxOverlay` renders an `<img>` or a `<video controls playsinline>` swapped by `kind` for the active index; `lightbox_controller.js` `render()` switches element type, **pauses any playing video on close/navigate**, and keeps the portal/`turbo:before-cache`/focus-trap behaviour intact. `Views::Trips::Gallery#gallery_images` → `gallery_media`: merge `entry.images` and `entry.videos.ready` into one ordered list; video tiles use `poster` as `thumb_url` + a ▶ badge overlay. `JournalEntryCard` cover/grid likewise includes ready videos.

Tailwind JIT: any new utility classes (e.g. ▶ badge, aspect ratios for the player) need `bin/cli app rebuild` (Phase 22 lesson — call it out in the runtime checklist).

---

## 10. Accessibility & Data-Respect Requirements

Non-negotiable; `/ux-review` + `/ui-polish` will check:
- Autoplayed video is **always muted** and `playsinline`; visible, reachable controls; a real `<button>`/native controls (keyboard operable).
- **`prefers-reduced-motion: reduce`** → no autoplay anywhere (card, gallery, lightbox); poster + explicit play only.
- **Save-Data / slow connection** → no autoplay, `preload="none"`, explicit tap to load/play; never burn mobile data uninvited.
- Poster always present so layout is stable and something is visible pre-load (no CLS); set width/height/aspect from stored dimensions.
- Lightbox video: focus management identical to Phase 22 (focus trap, ESC, restore focus); ESC/close **pauses** the video.
- `<video>` has an accessible name (aria-label from the entry/caption); decorative autoplay loops are muted and non-essential.
- IntersectionObserver pause-when-offscreen prevents background audio/CPU/data drain.

---

## 11. Edge Cases

| Case | Expected |
|---|---|
| ffmpeg/ffprobe absent (dev/CI) | Ingest duration-probe → `Failure` with a clear message; job → video `failed` (never crash). **Mitigated by the infra task** — but code must degrade, not 500 (Phase 22 `LoadError`-style discipline; note `Errno::ENOENT` from a missing binary is *not* a `StandardError` subclass issue but a normal exception — still rescue broadly in the job). |
| Video still `pending`/`processing` when page renders | Poster/placeholder tile, no broken `<video>`; gallery/lightbox skip it as a playable slide or show poster with "optimizing". |
| `failed` video | Small "unavailable" placeholder; entry/gallery still render; not enqueued again automatically. |
| HEVC/.mov from iPhone | Accepted at ingest (`video/quicktime`); transcode normalizes to H.264 MP4 — the whole point of optimization. |
| Over duration / over size | Rejected at ingest with explicit message (agent sees it in-band like image errors). |
| Huge upload via web form | Document Rack/proxy (`client_max_body_size`) limit as ops; consider a soft form hint. Agent path uses URL (no body limit). |
| Duration unprobeable / corrupt file | Ingest `Failure`; if it slips through, job → `failed`. |
| Many videos in gallery | Posters are small images (variant-like); only the in-view/opened video loads (`preload`, IO). N+1: eager-load `videos: { … attachments }` in `TripsController#gallery` and the trip show query (mirror Phase 22's `includes` fix). |
| Turbo cache / SPA nav while a video plays | Controller `disconnect()` pauses + disconnects observer; lightbox `turbo:before-cache` discipline preserved. |
| Reaction/comment on entries with video | Unchanged — video is additive to the association graph only. |
| Deleting an entry/video | `dependent: :destroy` cascades `JournalEntryVideo`; Active Storage purges source/web/poster. |

---

## 12. Implementation Blueprint

```
0. INFRA FIRST  ── ffmpeg+ffprobe in Dockerfile (same apt line as libvips) AND
   .github/workflows/ci.yml (step mirroring "#145 Install libvips in CI").
   Rebuild; prove `ffmpeg -version` in the container. Gates everything.
1. Migration + JournalEntryVideo model + JournalEntry has_many :videos.
   Run migrate; schema.rb regenerated (RailsSchemaUpToDate green).
2. JournalEntries::AttachVideos  (clone AttachImages: SSRF stack verbatim,
   tempfile streaming, ffprobe duration gate) + spec.
3. JournalEntries::UploadVideos  (clone UploadImages, base64, small ceiling) + spec.
4. journal_entry.videos_added event + JournalEntrySubscriber case +
   AuditLog::Builder "videos_added" mapping.
5. ProcessJournalVideosJob  (transcode + poster + probe; idempotent; rescue→failed) + spec.
6. Tools::AddJournalVideos / Tools::UploadJournalVideos + register in
   TripJournalServer::TOOLS + update instructions + app/mcp/README.md + spec.
7. Components::VideoPlayer + video_player_controller.js
   (IntersectionObserver, autoplay-policy, reduced-motion, Save-Data).
8. Generalise Components::Lightbox / LightboxOverlay / lightbox_controller.js
   to media items (kind: image|video); keep portal/turbo-cache/focus-trap.
9. JournalEntryCard + Views::Trips::Gallery → unified media list
   (images + ready videos; poster+▶ tiles; controller eager-loads videos).
10. journal_entry_form video file field + permit { videos: [] } + create/update wiring.
11. ui_library entries (VideoPlayer, unified Lightbox/Gallery) + regen index.
12. Specs: actions, job, MCP request, :js system (upload→process→play; gallery
    unified; reduced-motion/save-data) + :with_video factory trait.
13. Stitch design pass (player states + unified gallery) — §17.
14. bin/cli app rebuild + full /product-review runtime walk.
```

Error-handling strategy: ingest validates and fails fast with readable messages (agent-visible, like images); the job is the only place transcoding can fail and it converts failure into `video.status=:failed` + logged `error_message` — it never re-raises (a bad clip must not break the journal feed, mirroring `ProcessJournalImagesJob` and the Phase 22 "never 500" discipline). Missing-binary (`Errno::ENOENT`) is caught in the same broad job rescue.

---

## 13. Task List (ordered)

Per `/execution-plan`: GitHub issue first (label `enhancement`), Kanban Backlog→Ready→In Progress, branch `feature/phase-23-video-support`, **atomic commits** (`feat(scope): …`, or `#<issue> …` in remediation rounds), `prompts/Phase 23 - Steps.md` flight recorder updated each step, `/product-review` before PR, then PR + In Review, and (new in this repo) **Step 13/Release Rules**: after rebase-and-merge, `gh release create phase-23 --generate-notes`.

Delivered as **two tracks**, each its own issue → branch → PR → release (`/execution-plan` + Release Rules `phase-23a` / `phase-23b`). 23a is a hard prerequisite of 23b's web-form path.

**Track 23a — Storage & Direct Upload (= issue [#44](https://github.com/joel/trip/issues/44))**
1. `feat(issue)` — issue (link #44) + Kanban + open `prompts/Phase 23a - Steps.md`.
2. `feat(infra): run SeaweedFS service` in the project orchestration (alongside mail; `bin/cli`/Compose) + create bucket.
3. `feat(config): point Active Storage at :seaweedfs` (dev/prod envs) + verify attach/serve round-trip.
4. `feat(upload): Active Storage Direct Upload client` — `bin/importmap pin @rails/activestorage` (preferred) or hand-rolled Stimulus uploader → `/rails/active_storage/direct_uploads`.
5. `test:` round-trip smoke (large image via direct upload lands in SeaweedFS, attaches by `signed_id`) + system spec.
6. Runtime verify → PR → release `phase-23a`.

**Track 23b — Video (builds on 23a)**
1. `feat(issue)` — issue + Kanban + open `prompts/Phase 23b - Steps.md`.
2. `chore(ci): install ffmpeg in CI` **and** `build(docker): add ffmpeg to image` — **infra first**, verified before feature code (Phase 22 `#145` precedent).
3. `feat(db): JournalEntryVideo model + migration` (+ `JournalEntry has_many :videos`).
4. `feat(actions): AttachVideos` (SSRF stack reused, tempfile stream, ffprobe duration gate) + spec.
5. `feat(actions): UploadVideos` (base64, small ceiling) + spec.
6. `feat(events): videos_added event, subscriber, audit mapping`.
7. `feat(jobs): ProcessJournalVideosJob` (ffmpeg ≤720p + poster; idempotent; rescue→failed) + spec.
8. `feat(mcp): AddJournalVideos + UploadJournalVideos tools` + register in `TripJournalServer::TOOLS` + instructions + `app/mcp/README.md` + spec.
9. `feat(ui): Components::VideoPlayer + video_player_controller.js` (IO + autoplay-policy + reduced-motion + Save-Data).
10. `refactor(ui): generalise Lightbox/Gallery/controller to media items` (preserve portal / turbo:before-cache / focus-trap).
11. `feat(ui): unified media in JournalEntryCard + trip Gallery` (eager-load `videos`).
12. `feat(ui): video field in JournalEntryForm via Direct Upload` (consumes 23a; attach by `signed_id`).
13. `docs(ui_library): register VideoPlayer + unified components; regen index`.
14. `test:` action/job/MCP/system specs + `:with_video` factory + rack_test parity.
15. `docs: Phase 23 Stitch brief` + run Stitch MCP (§17).
16. Runtime: `bin/cli app rebuild && app restart && mail start` → §16 checklist.
17. `/security-review` (SSRF reuse, ffmpeg arg-injection, upload limits, direct-upload signed_id) → `/qa-review` → `/ux-review` → `/ui-polish` → `/qa-remediation` → PR → release `phase-23b`.

> Issue [#147](https://github.com/joel/trip/issues/147) (rendition ladder / HLS) is **out of both tracks** — deferred, opened, acted on only if Option A proves insufficient.

---

## 14. Testing Strategy

| Level | What | Where |
|---|---|---|
| Action (RSpec) | `AttachVideos`: HTTPS-only, SSRF blocks (reuse image spec cases), size/duration/count limits, content-type allowlist, creates `JournalEntryVideo(:pending)` + emits event. `UploadVideos`: base64 decode, Marcel type, ceiling. | `spec/actions/journal_entries/{attach,upload}_videos_spec.rb` (mirror image specs) |
| Job | `ProcessJournalVideosJob`: pending→ready (web+poster attached, duration/dims set), idempotent (skips non-pending), failure path sets `failed`+`error_message` and does **not** raise. Use a tiny real fixture clip; assert ffmpeg invoked (or stub the shell-out and assert args). | `spec/jobs/process_journal_videos_job_spec.rb` |
| MCP request | `add_journal_videos` / `upload_journal_videos` happy + error in-band; tool registered. | `spec/requests/mcp_spec.rb` (extend) |
| System (`:js`) | Real journey: attach video (factory) → job runs → entry card shows poster then player; gallery shows video tile + ▶; open unified lightbox, video plays, ESC pauses+closes; **reduced-motion** (emulate) → no autoplay; Save-Data → no autoplay. | `spec/system/journal_entry_videos_spec.rb`, extend `trip_gallery_spec.rb` |
| Factory | `:with_video` trait on `:journal_entry` attaching a small real MP4 fixture (mirror `:with_images` building a real blob). A tiny ≤1 s test clip committed under `spec/fixtures/files/`. | `spec/factories/journal_entries.rb` |

Real-journey rule (PROJECT SUMMARY): a poster rendering ≠ pipeline working — the system spec must run the actual job and assert `status: :ready` + a playing `<video>`, and check the `videos_added` event/audit row. CI driver split (`spec/support/system_test.rb`): playback specs **must** be `:js` (selenium); the rack_test default can't play media. ffmpeg must be in CI (task 2) or these fail exactly like Phase 22's libvips.

---

## 15. Validation Gates (Executable)

Run under the project Ruby (`mise x --`; chain the activation per the ruby-version-manager skill):

```bash
mise x -- bundle exec rake project:fix-lint
mise x -- bundle exec rake project:lint
mise x -- bundle exec rake project:tests
mise x -- bundle exec rake project:system-tests
# CI parity for the driver split (Phase 22 lesson):
mise x -- env TEST_BROWSER=rack_test bundle exec rspec spec/system
```

- Overcommit must pass: **`RailsSchemaUpToDate`** (run the migration before committing the model — do not `SKIP` it without a real reason), RuboCop, trailing whitespace, no FIXME, capitalised subject, no trailing period, body width. Genuine false positive → `SKIP=<Hook>` + commit-body footnote only.
- **No `[skip ci]`** (project rule); `.github/workflows/ci.yml` `paths-ignore` already exempts `*.md`/`prompts/**`/etc. — runtime code here is not exempt.
- **ffmpeg gate (load-bearing):** before feature work, `docker exec catalyst-app-dev ffmpeg -version` and `ffprobe -version` must succeed, and CI must show the install step green. If skipped, ingest/job/`:js` specs fail with binary-missing errors that masquerade as logic bugs (the Phase 22 libvips failure pattern, verbatim).
- **Tailwind JIT gate:** new utility classes need `bin/cli app rebuild` before the player/gallery render correctly.

---

## 16. Runtime Test Checklist

Per CLAUDE.md §5, live via `agent-browser` after `bin/cli app rebuild && app restart && mail start`, before PR:

- [ ] `ffmpeg -version` / `ffprobe -version` succeed in the container
- [ ] Agent path: `add_journal_videos` with an HTTPS MP4 URL → tool success; `JournalEntryVideo` row `pending`
- [ ] `ProcessJournalVideosJob` runs (Solid Queue) → row `ready`, `web` + `poster` attached, duration/dims set
- [ ] Entry card shows poster, then player; muted autoplay where permitted; pauses when scrolled out (IntersectionObserver)
- [ ] Trip Gallery shows the video as a poster tile with ▶, alongside images, in one flat grid
- [ ] Unified lightbox: open video item → plays; arrow/next to an image works; ESC pauses + closes; focus restored
- [ ] `prefers-reduced-motion` (emulate) → no autoplay anywhere
- [ ] Save-Data / slow connection (emulate) → no autoplay, no heavy preload
- [ ] Oversize / too-long / wrong-type upload → clear in-band rejection
- [ ] `failed` video → "unavailable" placeholder; feed/gallery still render
- [ ] Web form: select a video → uploads, processes, plays
- [ ] Dark mode; mobile viewport; no console/network errors on any touched page

---

## 17. Google Stitch Plan

Mirror Phase 22 §17 / `prompts/Phase 22 - Image Experience - Google Stitch Prompt.md` exactly (the **Catalyst Glass** design system, `assets/3c209c99f89947168c4e8320f9465cdc`, project `3314239195447065678`, is already established — *apply, do not invent*; structure/placement/states only):

1. Write `prompts/Phase 23 - Video Support - Google Stitch Prompt.md` as the MCP input brief. Surfaces & states: **VideoPlayer** (poster/idle, playing, paused, optimizing, failed, reduced-motion poster-only); **video tile in the unified gallery grid** (poster + ▶ badge, beside image tiles, one flat grid — consistent with Phase 22 Q4); **unified lightbox** with a video slide (controls, caption, prev/next to images). Reuse the Phase 22 preamble verbatim.
2. Run the Stitch MCP flow: `list_design_systems` → confirm Catalyst Glass id → `list_projects`/`get_project` → `generate_screen_from_text` (player + unified gallery) → `apply_design_system` → `get_screen`. Save under `designs/stitch_video_player/` (sibling of `designs/stitch_trip_gallery/`). Async timeout is expected (Phase 22 precedent) — if the screen doesn't materialise in-session, proceed from the captured design system + the Phase 22 gallery as the canonical sibling, and **record the divergence in `prompts/Phase 23 - Steps.md`** (token system is authoritative; never invent visuals).

---

## 18. Documentation Updates

- `app/mcp/README.md` — video tools, allowed types, limits, URL-vs-base64 guidance, the `journal_entry.videos_added` event.
- `app/actions/README.md` — add the video action/event/job to the diagram + event inventory (mirrors the `images_added` row).
- `ui_library/video_player.yml`, updated `lightbox.yml`/`trips_gallery.yml` (now media, not image-only); regenerate `ui_library/index.html` via `ruby ui_library/generate_index.rb`.
- `prompts/Phase 23 - Steps.md` — flight recorder, created at task 1, appended each step (issue/branch/sha/runtime/PR-review/release), per the execution-plan audit-trail rule.
- PROJECT SUMMARY Domain bullet: note `JournalEntry has_many :videos` once shipped.
- If the unified-media lightbox pattern proves reusable, add a one-line planning-conventions note (defer).

---

## 19. Rollback Plan

Additive and reversible:
- Revert the UI commits → cards/gallery/lightbox return to image-only (Phase 22 behaviour); no data touched.
- Revert MCP/action/job/event commits → no video ingestion; existing entries unaffected.
- The migration is the only non-trivial undo: `rails db:rollback` drops `journal_entry_videos` (and cascades its Active Storage attachments). No change to `journal_entries`, `images`, or any Phase 22 table — Phase 22 surfaces keep working throughout.
- Infra (ffmpeg) is purely additive to the image/CI; harmless if feature reverted.
No destructive data migration, no change to the image pipeline.

---

## 20. Out of Scope / Future Phase

- HLS / DASH adaptive bitrate, multi-rendition ladder (brief: "*consider*").
- In-browser recording/trimming/editing, scrub-thumbnails, chapters.
- Captions/subtitles/transcription, audio-only media, live streaming.
- Direct-to-storage resumable uploads (tus); SeaweedFS/CDN tuning (#44).
- Per-trip storage quotas/retention; video analytics.
- Reordering/cover-selection of mixed media (image vs video) — beyond `position`.

---

## 21. Reference Documentation

- Active Storage — **Direct Uploads** (signed URL → `PUT` to service → `signed_id`): https://guides.rubyonrails.org/active_storage_overview.html#direct-uploads
- `@rails/activestorage` JS (pin via importmap CDN — no npm): https://www.npmjs.com/package/@rails/activestorage (pin source only) / https://github.com/rails/rails/tree/main/activestorage/app/javascript/activestorage
- SeaweedFS S3 API (the `seaweedfs:` stanza in `config/storage.yml`): https://github.com/seaweedfs/seaweedfs/wiki/Amazon-S3-API ; issue [#44](https://github.com/joel/trip/issues/44)
- Active Storage — analyzing & previewing (video metadata via ffprobe, preview via ffmpeg): https://guides.rubyonrails.org/active_storage_overview.html#analyzing-files , https://guides.rubyonrails.org/active_storage_overview.html#previewing-files
- `config.active_storage.video_preview_arguments` / `variant_processor`: https://guides.rubyonrails.org/configuring.html#config-active-storage-video-preview-arguments
- Active Job basics (async jobs, retries): https://guides.rubyonrails.org/active_job_basics.html
- ffmpeg H.264 web encoding & `-movflags +faststart`: https://trac.ffmpeg.org/wiki/Encode/H.264 , https://trac.ffmpeg.org/wiki/Encode/YouTube
- ffprobe (duration/streams JSON): https://ffmpeg.org/ffprobe.html
- MDN — Autoplay guide & policies (muted + playsinline requirement): https://developer.mozilla.org/en-US/docs/Web/Media/Autoplay_guide
- MDN — `<video>` element (`poster`, `preload`, `playsinline`, `<source>`): https://developer.mozilla.org/en-US/docs/Web/HTML/Element/video
- MDN — Intersection Observer API: https://developer.mozilla.org/en-US/docs/Web/API/Intersection_Observer_API
- MDN — `prefers-reduced-motion`: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion
- MDN — `NetworkInformation.saveData` / `effectiveType`: https://developer.mozilla.org/en-US/docs/Web/API/NetworkInformation/saveData
- (Only if HLS is later pursued) hls.js, via importmap CDN pin — no npm: https://github.com/video-dev/hls.js
- (Optional ingestion/probe helper, vs raw shell-out) streamio-ffmpeg: https://github.com/streamio/streamio-ffmpeg
- In-repo precedents (read directly): `app/actions/journal_entries/attach_images.rb`, `upload_images.rb`; `app/jobs/process_journal_images_job.rb`; `app/subscribers/journal_entry_subscriber.rb`; `app/mcp/tools/add_journal_images.rb`; `app/components/lightbox*.rb` + `app/javascript/controllers/lightbox_controller.js`; `app/views/trips/gallery.rb`; Phase 22 commit `#145 Install libvips in CI`; `prompts/Phase 22 - Image Experience - Google Stitch Prompt.md`.

---

## 22. Quality Checklist

- [x] All necessary context included (exact precedent files + the image→video clone map)
- [x] Validation gates executable by the AI (`rake project:*`, rack_test parity, ffmpeg gate, overcommit)
- [x] References existing patterns (images pipeline, Export async-model, Phase 22 lightbox/gallery, `#145` infra)
- [x] Clear implementation path (infra-first ordered task list + pseudocode blueprint)
- [x] Error handling documented (fail-fast ingest; job converts failure → `status:failed`, never re-raises; missing-binary degradation)
- [x] Accessibility & data-respect specified up front (reduced-motion, Save-Data, muted autoplay, focus, no-CLS poster)
- [x] Open assumptions surfaced for approval (§1 Q1–Q5, none pre-resolved)

**Confidence: 6/10** one-pass (≈7/10 with the §1 recommended narrowed scope: model-based, single rendition, full unification). Risk concentrated in: the ffmpeg infra change (must land first, exact Phase 22 libvips precedent), correct/resilient ffmpeg shell-outs, the unified-media lightbox extension of the Phase 22 contract, and net-new connection-aware/reduced-motion autoplay JS. Everything else has a direct in-repo template.

---

> **APPROVED (2026-05-17).** §1 Q1–Q5 resolved; #147 (deferred ladder/HLS) opened; sequencing = **SPLIT 23a → 23b**; Direct Upload client = **`@rails/activestorage` importmap pin**. Execution begins with **Track 23a** (SeaweedFS/#44 + Direct Upload) via `/execution-plan`; **Track 23b** (video) starts only after 23a ships and is verified. #147 stays deferred.
