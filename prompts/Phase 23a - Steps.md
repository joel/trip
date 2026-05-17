# Phase 23a — SeaweedFS + Direct Upload · Steps (flight recorder)

Append-only. Why and in what order, readable top-to-bottom.

---

## Step 1 — Issue

- **Issue:** [#148](https://github.com/joel/trip/issues/148) — "Phase 23a: SeaweedFS storage service + Active Storage Direct Upload"
- **Refs:** [#44](https://github.com/joel/trip/issues/44) (prod cutover/migration stays its own item)
- **Plan:** `prompts/Phase 23 Video Support.md` (= `PRPs/phase-23-video-support.md`), §13 Track 23a
- User approved the plan 2026-05-17: split 23a→23b; Direct Upload via `@rails/activestorage` importmap pin. Q1–Q5 resolved; #147 (ladder/HLS) deferred.
- Label: `enhancement`.

## Steps 2–12 — Implementation (branch feature/phase-23a-seaweedfs-direct-upload)

| sha | what |
|-----|------|
| 6d129d1 | docs(phase-23): plan/PRP + 23a steps |
| ff1519b | aws-sdk-s3 (require:false) for the S3 Active Storage service |
| 645494c | `bin/cli storage` SeaweedFS service (standalone like mail; Traefik TLS host, volume, S3 CreateBucket via HTTP; app+example.env SEAWEEDFS_*) |
| aae74c2 | Active Storage → :seaweedfs (dev+prod; ssl_verify_peer prod-gated); verified blob round-trip |
| e3f6b9f | importmap pin @rails/activestorage; form `direct_upload: true` |
| 35a1d8f | direct-upload system spec (non-JS data attr + :js end-to-end) + pixel.png fixture |
| c0a42db | scope Active Storage to a form Stimulus controller (lazy dynamic import; off global JS path) |

**Decisions / deviations**
- `bin/cli storage` is standalone (like `mail`), **not** wired into `ServicesManager` — follows the actual in-repo precedent over the PRP's assumption.
- Direct Upload client: `@rails/activestorage` pinned to the **gem-shipped `activestorage.esm.js`** (consistent with the actioncable/actiontext pins) — better than `bin/importmap pin` (no CDN). Started by a **form-scoped Stimulus controller with a lazy dynamic import**, not global `application.js` (keeps AS off every other page's JS-boot path).
- SeaweedFS S3 CreateBucket via `PUT /<bucket>` (anonymous; no `-s3.config`) — the `weed shell` path was flaky on a fresh single node.

**Verification**
- Blob create/upload/download/purge round-trips through SeaweedFS S3 (`rails runner`).
- `direct_upload_spec`: non-JS asserts `data-direct-upload-url`; `:js` does a real direct upload → `DirectUploadsController` blob → browser PUT → form submits `signed_id` → entry attaches & renders. 2/2 green (selenium).
- Gate: `project:lint` 493/0; non-system 768/0 (2 pre-existing pending); **system rack_test (CI parity) 90/0**.

**Pre-existing, NOT Track 23a (documented, like Phase 22's audit specs):**
`spec/system/welcome_spec.rb` fails 4/7 **under selenium only when compiled Tailwind CSS is present** — it races the app-wide `ha-fade-in` entry animation in `application_layout.rb` (untouched by 23a). Proven by bisection: **identical 4/7 failure on a clean `main` worktree with CSS built**; "passes" only with no compiled CSS (no animation). CI runs these under **rack_test** (no CSS engine) → green (90/0 above). Not gating; tracked in #149, out of 23a scope (modifying it would mask a pre-existing app-wide concern).

## Step 8 — Live runtime verification (agent-browser) — caught 2 real bugs

Rebuilt/restarted; SeaweedFS up; signed in as joel@acme.org; created a contributor trip; uploaded an image through the journal-entry form (direct upload). Two genuine runtime gaps found and fixed (commit `ca19dff`):

1. **CORS** — the cross-origin browser PUT (app host → storage host) was blocked (no bucket CORS). `StorageService#ensure_cors` now applies a `PutBucketCors` policy for the app origin on `bin/cli storage start`. Verified: preflight returns `access-control-allow-origin`.
2. **App→storage reachability** — the app container could not reach `storage.workeverywhere.docker:443` (Connection refused; that host → Traefik only on the host). Presigned URLs bind the host, so server-side blob ops must use the same host. Added `--add-host=storage.workeverywhere.docker:host-gateway` (dev) so the container routes to the host Traefik. Prod resolves it for real (#44).

**End-to-end verified:** browser direct-uploads bytes to SeaweedFS → form submits `signed_id` → entry attaches → `blob.service_name=seaweedfs` → server downloads it back OK → image renders via Active Storage representation on the trip page.

## Step 9 — Validation (authoritative gate)

- `project:lint` 493/0; non-system 768/0 (2 pre-existing pending).
- `system rack_test` (CI parity) 90/0 on a clean run; one later run flaked on `trip_gallery_spec.rb:21` (a **Phase 22 `:js` selenium test**, passes 2/2 in isolation) — same pre-existing selenium-under-load fragility family as #149, not a Track 23a regression (final commits were `bin/cli`-only, not loaded by specs). CI gate (rack_test, non-`:js`) unaffected.
- `direct_upload_spec` 2/2 (selenium).
