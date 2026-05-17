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
