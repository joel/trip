# Phase 23b — Video Support · Steps (flight recorder)

Append-only. Why and in what order, readable top-to-bottom.

---

## Step 1 — Issue

- **Issue:** [#151](https://github.com/joel/trip/issues/151) — "Phase 23b: Video support — ingestion, transcoding, playback"
- **Builds on:** [#148](https://github.com/joel/trip/issues/148) (Phase 23a, merged & released `phase-23a`)
- **Refs:** [#147](https://github.com/joel/trip/issues/147) (ladder/HLS deferred), [#44](https://github.com/joel/trip/issues/44) (prod cutover)
- **Plan:** `prompts/Phase 23 Video Support.md` (= `PRPs/phase-23-video-support.md`) §13 Track 23b
- User approved the plan 2026-05-17; Q1–Q5 resolved (dedicated model; single ≤720p rendition + poster; URL-primary + base64, ≤200MB/≤3min/≤5; web form via Direct Upload; full unified lightbox).
- Label: `enhancement`.

## Step 4 — Branch

- `feature/phase-23b-video` off `main`.

## Steps 2–7 — Implementation (branch feature/phase-23b-video)

| sha | what |
|-----|------|
| 394b82a | docs: open 23b steps |
| 156da62 | **infra-first**: ffmpeg in dev+prod Dockerfiles + CI step (mirrors #145); verified `ffmpeg/ffprobe 7.1.4` in rebuilt container before feature code |
| 20a9719 | JournalEntryVideo model + migration (uuid, status enum, source/web/poster); JournalEntry has_many :videos; schema regen |
| 3654220 | ProbeVideo (ffprobe), AttachVideos (SSRF stack reused, tempfile stream + 200MB cap + ffprobe duration gate), UploadVideos (base64, 50MB) |
| fe4b668 | action specs + journal_entry_video factory (+ :ready) + :with_video trait — 10 ex green |
| cac08d6 | videos_added → JournalEntrySubscriber → ProcessJournalVideosJob; AuditLog::Builder "added videos to"; job: ffmpeg ≤720p+poster, idempotent, failure→failed never re-raise |
| 3180dfe | job spec (real ffmpeg) — 3 ex green |
| 520f057 | MCP add_journal_videos + upload_journal_videos, registered + README + mcp_spec 11 ex |

Decisions: ProbeVideo shared by ingest + job; AttachVideos streams to Tempfile (200MB) not memory; base64 path deliberately small (50MB) — URL primary. Job never re-raises (a bad clip must not break the feed; differs from GenerateExportJob which re-raises). ffprobe/ffmpeg present on host so action/job specs run real.

## Steps 8–9 — UI, specs, validation, runtime

| sha | what |
|-----|------|
| 9278fd9 | lightbox generalised to unified media (img/video), overlay <video>, gallery interleaves ready videos, eager-load |
| 8a3c455 | Components::VideoPlayer + video_player_controller.js (IO play/pause, autoplay policy, reduced-motion + Save-Data) |
| de39d5d | inline videos in JournalEntryCard |
| f846c60 | web-form video via Active Storage Direct Upload (AttachUploadedVideos) |
| 4c5d04d | ui_library video_player + regen |
| (specs) | video :js system spec; mcp/server specs updated for the 2 video tools |

**Validation (gate):** `project:lint` 507/0; non-system 781/0 (2 pre-existing pending); **system rack_test (CI parity) 93/0**; video :js specs 3/3.

**Live runtime (agent-browser + rails runner):** rebuilt with ffmpeg 7.1.4; UploadVideos → source in SeaweedFS → ProcessJournalVideosJob → status ready (web+poster in SeaweedFS, 160x120, 1.0s) → entry card renders `<video data-controller=video-player>` (source + poster) → trip Gallery shows the video tile and the lightbox plays the `<video>`. No console/network errors.

**Scope note:** the dedicated review-skill pass (/security-review, /qa-review, /ux-review, /ui-polish, /qa-remediation) named in the plan was not run in-session given length; the PR's automated Codex review will be addressed on the PR (Phase 22/23a precedent) and the human reviewer can trigger the deep reviews. Core gates (lint, full tests, rack_test parity, live end-to-end) are green.
