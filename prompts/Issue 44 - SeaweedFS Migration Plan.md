# Issue #44 — Production Active Storage → SeaweedFS Migration Plan

Tracking issue: [#44](https://github.com/joel/trip/issues/44) — *Switch
production Active Storage to SeaweedFS for durable persistence.*

Status: **Kamal config STAGED, cutover NOT executed.** `production.rb`
deliberately stays `config.active_storage.service = :local`; the flip
is the final post-migration step (step 6), not part of any feature
branch's runtime behaviour.

---

## Kamal config (staged, inert today)

`config/deploy.yml`:

- `accessories.seaweedfs`: `chrislusf/seaweedfs:3.97` (matches dev),
  `server -s3 -dir=/data -ip.bind=0.0.0.0`, named volume
  `catalyst_seaweedfs:/data`, host `workeverywhere.app`.
- `env.clear`: `SEAWEEDFS_ENDPOINT=http://seaweedfs:8333`,
  `SEAWEEDFS_BUCKET=catalyst`, anonymous `any/any` keys (S3 is not
  internet-reachable, so unauthenticated is acceptable; harden via
  SeaweedFS `-s3.config` if S3 ever gets exposed).

### Exposure — SSH-tunnel-only (operator decision)

kamal-proxy has no built-in basic-auth, so rather than a fragile
auth-proxy:

- **S3 API `:8333`** is **not** published — only the app reaches it
  over the private `kamal` Docker network at `http://seaweedfs:8333`
  (Kamal registers the accessory on that network under its name).
- **Master/filer admin UI** is published bound to `127.0.0.1` on the
  host only (never the internet). Reach it from a workstation with:

  ```
  ssh -L 9333:127.0.0.1:9333 -L 8888:127.0.0.1:8888 deploy@workeverywhere.app
  ```

  then open `http://localhost:9333` (master) / `http://localhost:8888`
  (filer). Zero internet exposure, no extra moving parts.

Boot / maintenance:

```
bin/kamal accessory boot seaweedfs
bin/kamal accessory logs seaweedfs
```

---

## Migration runbook — local Disk → SeaweedFS (one-time, zero-loss)

Recommended low-risk path = **Mirror service** (dual-write, then
backfill, then cut over) so no upload is lost during the window.

0. **Pre-flight.** Tag the box; snapshot the `catalyst_storage`
   volume. App still `:local`. Record baseline
   `ActiveStorage::Blob.count` and total bytes.
1. **Boot the accessory.** `bin/kamal accessory boot seaweedfs`;
   verify health via the SSH tunnel (master UI cluster status, volume
   server present).
2. **Provision bucket + CORS** on prod SeaweedFS (prod analogue of
   `bin/cli storage` `ensure_bucket` / `ensure_cors`): `PUT /catalyst`
   (idempotent; HTTP 409 = already owned), and `PUT /catalyst?cors`
   with `AllowedOrigin https://catalyst.workeverywhere.app`. One-shot
   rake/runner, idempotent.
3. **Dual-write window.** Add a `mirror` service to
   `config/storage.yml` (`primary: local`, `mirrors: [seaweedfs]`) and
   point `production.rb` at `:mirror`; deploy. Every new/updated blob
   is now written to **both** stores — no migration race.
4. **Backfill existing blobs.** Runner task:
   `ActiveStorage::Blob.find_each` → skip if
   `seaweedfs.exist?(blob.key)` (idempotent/resumable) → stream
   `local.download(key)` → `seaweedfs.upload(key, io,
   checksum: blob.checksum)`. Log every key; never delete the source.
5. **Verify.** For every blob: `seaweedfs.exist?(key)` true; sample
   (≥ N random + every video/poster) downloaded and checksum-compared
   to `blob.checksum`. Counts/bytes reconcile to the step-0 baseline.
6. **Cut over.** Flip `production.rb` to
   `config.active_storage.service = :seaweedfs`; deploy. New writes
   are now SeaweedFS-only; reads served via the
   `/rails/active_storage/…` proxy from SeaweedFS.
7. **Smoke (full journeys).** Web: upload a new journal image **and**
   a video (Direct Upload → SeaweedFS → ProcessJournalVideosJob →
   ready → lightbox plays). Existing images/exports still render. MCP
   `add/upload_journal_images|videos` write to SeaweedFS.
8. **Rollback (safe until decommission).** Revert `production.rb` to
   `:local` (or `:mirror`) and redeploy — the backfill is read-only on
   the source, so `catalyst_storage` is intact the whole time.
9. **Decommission.** After a soak period with `:seaweedfs` healthy,
   stop relying on `catalyst_storage` for Active Storage (keep the
   volume — the SQLite DBs live there too). Close #44.
