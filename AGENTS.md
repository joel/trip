# AGENTS.md

This document provides instructions and protocols for AI Agents interacting with this repository. **Follow these guidelines strictly to ensure project consistency.**

## 1. Context & Environment

- **Location Awareness:** Always use `context7` to retrieve the latest version of the project location and environmental state before performing actions.

- **Live Testing:** Use the `agent-browser` tool to verify changes visually or functionally.

- **GitHub CLI:** Always `unset GITHUB_TOKEN` before running `gh` commands. The environment may have a stale token that causes `HTTP 401: Bad credentials` errors. The `gh` CLI falls back to its own auth store when the env var is unset.

    - **Local URL:** `https://catalyst.workeverywhere.docker`

---

## 2. CLI Operations (`bin/cli`)

Pilot the application and infrastructure through the CLI.

### Usage Syntax

`bin/cli COMMAND ACTION [ENV]`

| **Command** | **Description** |
|---|---|
| `app ACTION [ENV]` | Manage the application container. |
| `db ACTION [ENV]` | Manage the database container (migrations, reset, etc.). |
| `mail ACTION` | Manage the local mail service. |
| `services ACTION [ENV]` | Orchestrate all services together. |
| `tree` | Print a tree of all available commands. |
| `help [COMMAND]` | Describe available commands or one specific command. |

### Parameters

- **ACTION:** Common actions include `start`, `stop`, `build`, `logs`, `connect`, `console`, `reset`.

- **ENV:** Options are `dev` | `development` (default) or `prod` | `production`.

---

## 3. Development Workflow & Quality Control

### Pre-Commit Validation

You **must** run these commands and ensure they pass before attempting a commit:

1. **Linting:** `bundle exec rake project:fix-lint` (to autocorrect) then `bundle exec rake project:lint`.

2. **Testing:** `bundle exec rake project:tests` and `bundle exec rake project:system-tests`.

### Git & Overcommit Hooks

The project uses `overcommit`. Commits will fail if the following hooks are not satisfied:

- **Pre-commit:** Checks for trailing whitespace, "FIXME" tokens, and **RuboCop** compliance.

- **Commit-msg:** Enforces **Capitalized Subjects**, no trailing periods, and specific line widths.

- **Action:** If a hook fails, you must resolve the issue in the code or the commit message before re-committing.

---

## 4. Process & Governance

1. **Issue First:** No work without an existing issue in [GitHub Trip Issues](https://github.com/joel/trip/issues). Create one if needed.

2. **Kanban Management:** You are responsible for moving issues across the [Trip Kanban Board](https://github.com/users/joel/projects/2/views/1) (e.g., _To Do_ -> _In Progress_ -> _Done_).

3. **Repository:** All code must be pushed to the [GitHub Trip Repository](https://github.com/joel/trip).

### Workflow Steps

1. Read `AGENTS.md` / `CLAUDE.md` to understand current project rules.
2. Create an issue on [GitHub Trip Issues](https://github.com/joel/trip/issues) with a detailed plan, then move it to **Backlog** on the [Trip Kanban Board](https://github.com/users/joel/projects/2/views/1).
3. Add the appropriate label (e.g., `cleanup`, `feature`, `fix`) to the issue.
4. Before starting work, assign yourself to the issue and move it to **Ready**.
5. Once you start working, move the issue to **In Progress**.
6. Pre-commit validation must include **both** `bundle exec rake project:tests` **and** `bundle exec rake project:system-tests`.
7. When all tests pass and browser verification succeeds, push the branch, create the PR with a description, and move the issue to **In Review**.
8. After the PR receives review comments, you **must** respond to every comment, then resolve each conversation.
9. **After the PR is rebase-and-merged to `main`**, tag `main` and publish a GitHub release (see **Release Rules**), then move the issue to **Done**.

### PR Review Response Rules

When a PR receives code review comments:

1. **Read all comments** using `gh api repos/joel/trip/pulls/<PR>/comments`.
2. **Evaluate each comment** — decide whether to act on it, explain why not, or defer to a future phase.
3. **For actionable feedback:** Fix the code, commit, push, then reply explaining what was fixed and in which commit.
4. **For incorrect feedback:** Reply with a clear technical explanation of why no action is needed.
5. **For deferred feedback:** Reply acknowledging the concern and stating which phase or PR will address it.
6. **Reply to every comment** using `gh api repos/joel/trip/pulls/<PR>/comments/<ID>/replies -X POST -f body='...'`. The `<PR>` number is required — omitting it (`gh api repos/joel/trip/pulls/comments/<ID>/replies`) returns `HTTP 404: Not Found`.
7. **Resolve every conversation** after replying using the GraphQL `resolveReviewThread` mutation.
8. Never leave review comments unanswered or unresolved.

### Release Rules

Runs **only after the PR has been rebase-and-merged to `main`** by a human — the agent never merges. Once `main` contains the merge commit:

1. **Sync and verify.** `git checkout main && git pull origin main`. Confirm the merge commit is present and the `main` CI/Deploy run for it is green before releasing.
2. **Tag convention: `phase-N`.** Derive `N` from the phase plan (`prompts/Phase N ...`). One release per phase. Standalone work that is **not** a numbered phase gets **no** tag/release — skip this section entirely.
3. **Idempotent.** If the `phase-N` tag or release already exists, stop — never recreate or overwrite a published release.
4. **Tag + publish in one step** (auto-generated notes from merged PRs/commits since the previous tag):
   ```bash
   unset GITHUB_TOKEN && gh release create phase-N \
     --repo joel/trip --target main \
     --title "Phase N — <short title>" \
     --generate-notes
   ```
   `gh release create` creates the annotated tag on `main` and publishes the release at <https://github.com/joel/trip/releases> together. `--generate-notes` honours `.github/release.yml`, which **excludes Dependabot / `dependencies`-labelled PRs** so dependency bumps are kept out of phase release notes — do not re-add them.
5. **No deploy interaction.** `deploy.yml` triggers on the merge commit (branch push), **not** on tags — creating the tag/release does not re-deploy and needs no `[skip deploy]`.
6. **Audit trail.** Record the tag name and release URL in `prompts/Phase N - Steps.md`, then move the issue to **Done**.

### Workflow Rules

- **Never disable overcommit entirely** (`OVERCOMMIT_DISABLE=1`). When a hook indicates a false positive, skip **only** the specific hook: `SKIP=<HookName> git commit ...` (e.g., `SKIP=RailsSchemaUpToDate`). Always add a footnote in the commit message body explaining which hook was skipped and why, for audit trail purposes.

- **Do not use `[skip ci]` markers in commit messages.** CI decides whether to run via `paths-ignore` in `.github/workflows/ci.yml` (non-runtime paths such as `**/*.md`, `prompts/**`, `ui_library/**`, `PRPs/**`, `docs/**`, `designs/**`, `notes/**` are ignored automatically). Using `[skip ci]` caused CI to be skipped on `main` after rebase-and-merge when the PR's last commit carried the marker, even though the merged diff contained runtime changes. If a new directory should be exempt from CI, add it to `paths-ignore` instead of relying on commit-message markers.

- **Test full user journeys, not just page rendering.** Runtime tests must verify multi-step flows end-to-end (e.g., request access → admin approves → invitation email sent → user signs up → user verified). A page rendering correctly does not guarantee the business logic behind it works. If a feature involves events, subscribers, or background jobs, verify the downstream effects actually happen (check emails in MailCatcher, check database records).

- **Rails.event structured events (Rails 8.1).** Subscribers must respond to `#emit(event)`, not `#call`. The event is a hash: `event[:name]`, `event[:payload]`, `event[:tags]`, etc. Register with `Rails.event.subscribe(subscriber)` and use an optional filter block: `{ |e| e[:name].start_with?("prefix.") }`.

- **Shell escaping with `docker exec` + `bin/rails runner`.** Ruby bang methods (`save!`, `find_by!`) break in shell because `!` is interpreted by bash. Use heredoc redirect instead: `docker exec -i container bin/rails runner - < /tmp/script.rb`.

- **Rodauth forms lose query parameters on POST.** If a URL contains query params (e.g., `?invitation_token=xxx`), the Rodauth form POST will not include them. Add hidden fields in the Phlex view to carry params through.

- **Pre-fill forms from context, not just params.** When a URL carries context (tokens, IDs) that determines valid input, pre-fill and lock the relevant form fields. If the backend validates that an email matches an invitation, the form must pre-fill that email from the invitation record and make it read-only. Never rely on the user to type something that the system already knows — mismatches cause silent rejections that look like bugs.

---

## MCP Authentication and Agent Identity

MCP requests carry two pieces of identity:

1. **`MCP_API_KEY`** — shared Bearer token for the endpoint (channel auth). A valid key grants **unrestricted read/write access to all domain data** through the 23 registered MCP tools (journal entries, images, comments, reactions, checklists, plus read access to trips). Trip creation and member administration are deliberately not exposed — those remain human-only. Missing/wrong key → HTTP 401.
2. **`X-Agent-Identifier` header** — slug of a registered `Agent` record (e.g. `jack`, `maree`). Resolves to the agent's system User, which is used as the author/actor for all writes (journal entries, comments, reactions). Missing or unknown slug → JSON-RPC error `-32001` with a readable message (HTTP 200 so the client sees it in-band). Register agents via Rails console: `Agent.create!(slug: "...", name: "...", user: <system_user>)`.

Each agent has its own `@system.local` User. Subscription filters (`JournalEntries::Create#subscribe_trip_members`) exclude system actors from auto-subscription, so agents don't email themselves.

---

## Audit Journal (Phase 21)

Every `Rails.event` domain event is persisted as an append-only `AuditLog` row by `AuditLogSubscriber` → `AuditLog::Builder` → `RecordAuditLogJob` (off the request path; idempotent on `event_uid`).

- **Actor attribution.** `Current` (`ActiveSupport::CurrentAttributes`, set in `ApplicationController`/`McpController`) carries the actor. `Rails.event` dispatches subscribers **synchronously in the request thread** (verified), so `Current.actor` is populated when the subscriber runs. Resolution priority: payload `actor_id` → `Current.actor` → the record's owner → `nil` (labelled `System`). When adding a new event, prefer letting `Current` supply the actor; only the dirty diff must be added to the payload (`changes:`), because the async writer cannot reconstruct it.
- **Builder context after `destroy!`.** Delete/remove actions emit the event *after* `destroy!`, so `AuditLog::Builder#*_subject` must resolve `trip_id` (and any context) from **payload-carried sibling IDs**, never from `Model.find_by(primary_id)` — the primary record is gone, `find_by` returns `nil`, and the row is written `trip_id: nil` (an invisible app-wide row). Comments resolve via `journal_entry_id` (the entry survives a comment delete); reactions via `reactable_type`/`reactable_id` (mirrors `Reaction#trip`). Resolve **unconditionally** so created and deleted share one path. When adding an event with a deletion variant, put the trip/parent ID in its payload and add a builder spec for the *deleted* case — not only the created one (`journal_entry.deleted` passed only because its payload already carries `trip_id`).
- **Append-only.** `AuditLog#readonly?` returns `true` once persisted — rows are never updated or destroyed. Reverts are new forward events, not history edits.
- **Denormalised.** `actor_label`, `summary`, `metadata` are written at capture time so the feed renders join-free and survives deletion of the trip/actor/target.
- **`source` enum.** `web | mcp | telegram | system` — drives the feed's source badge.
- **Visibility.** Trip-scoped feed at `/trips/:id/activity` (`AuditLogPolicy`: superadmin or trip contributor). Viewers/guests are **hidden entirely** — `AuditLogsController` returns **404** (deliberate deviation from the app-wide `ActionPolicy::Unauthorized → 403`, so the feed's existence is not disclosed). App-wide (nil `trip_id`) rows + auth events are captured now; the superadmin General console is Phase 22.
- **Low-signal tier.** `reaction.*` and `checklist_item.toggled` are captured but hidden behind the feed's "Show low-signal" toggle.
- **Never block the user.** `AuditLogSubscriber` swallows and logs every error — a broken audit log must never break a user action.

---

## Persistence safety (Phase 25)

Three complementary safety nets on the user-authored models (`Trip`, `JournalEntry`, `Comment`): **soft delete** (`discard`), **versioning** (`paper_trail`), and the **AuditLog feed** (Phase 21) which surfaces Restore/Revert. Full write-up + diagrams in [`docs/persistence-safety.md`](docs/persistence-safety.md).

- **Delete means discard, not destroy.** The three `*::Delete` actions (`app/actions/{trips,journal_entries,comments}/delete.rb`) call `record.discard!`, never `destroy!`. A real `destroy` no longer fires for these models, so their `dependent: :destroy` associations (memberships, reactions, attachments) only run on an actual hard destroy — which the app no longer triggers. That is *why* restore recovers the whole graph: discard skips validations and `dependent: :destroy`, leaving the children intact.
- **`default_scope -> { kept }` is the safety guarantee.** Each model includes `Discard::Model` and scopes to `kept`, so discarded rows never leak into any read path — views, MCP `list_*`, exports, counts, and even Rails 8.1 `left_joins` ON-clauses. **Use `with_discarded` on every restore/admin/builder path** that must see deleted rows. `discarded_at` (datetime + index) was added by `db/migrate/*_add_discarded_at_to_critical_models.rb`.
- **`with_discarded.discarded`, never bare `.discarded`.** A bare `.discarded` self-contradicts the default scope (`discarded_at IS NULL AND IS NOT NULL` → empty). The trips trash view (`?discarded=1`) and `AuditLog::Builder` subject finders both go through `with_discarded` for exactly this reason.
- **Cascade is down-only.** `Trip after_discard { journal_entries.kept.find_each(&:discard) }`; `JournalEntry after_discard { comments.kept.find_each(&:discard) }`. There is **no `after_undiscard`** — restore is **parent-only** by design (`*::Restore` actions call `undiscard!` and emit `*.restored`).
- **Versioning lives in two places.** `JournalEntry` has `has_paper_trail only: %i[name]` (the **title**). The rich-text **body** is a separate `ActionText::RichText` row, versioned via `config/initializers/paper_trail_action_text.rb` — **not** a `journal_entries` column, so body edits never appear as Activity-feed column diffs (out of scope, intentional). Writes are wrapped in `PaperTrail.request(whodunnit: Current.actor&.id)` in `JournalEntries::Create`/`Update`.
- **JSON serializer is mandatory for `reify`.** `config/initializers/paper_trail.rb` sets `PaperTrail.serializer = PaperTrail::Serializers::JSON` — Psych 4 `safe_load` rejects `ActiveSupport::TimeWithZone` on reify (`Psych::DisallowedClass`). The `versions` table is UUID-corrected (`id: :uuid`, `t.uuid :item_id`) to match the app's UUID PKs.
- **Feed Restore vs Revert.** `AuditLogsController` computes two maps: `build_restorable` (keyed by `auditable_id`) puts a **Restore** button on `*.deleted` rows whose auditable is still discarded and whose parent chain is kept and `restore?` allows it; `build_revertable` (keyed by **audit_log id**, per-row) puts a **Revert** button on `*.updated` rows, re-applying `metadata["changes"]` olds through the record's Update action (a forward audit + version event). `restore?` was added to `Trip`/`JournalEntry`/`Comment` policies mirroring `destroy?`. Routes: `PATCH /trips/:id/{restore, activity/:id/revert}` and the nested entry/comment `restore`.

## Media soft-delete + restore (Phase 26)

Per-item soft-delete + restore for **images** and **videos**, surfaced as Restore on `*.removed` rows in the Activity feed. Extends Phase 25 to media. Two retention mechanisms because the two media kinds differ.

- **Videos discard the row.** `JournalEntryVideo` includes `Discard::Model` + `default_scope -> { kept }` (`discarded_at` via `db/migrate/*_add_discarded_at_to_journal_entry_videos.rb`). Discard keeps the row, so its `source`/`web`/`poster` attachments stay and the blobs are **never orphaned** — no `OrphanBlobsCleanupJob` interaction needed. `JournalEntry after_discard` cascades to videos. `JournalEntryVideos::{Delete,Restore}` emit `journal_entry_video.{removed,restored}`.
- **Entry restore cascade-restores its videos** (issue #206, release-scan fix). The entry cascade discards videos via raw `discard` (no event), so a parent-only restore would strand them with no feed button. `JournalEntries::Restore` therefore captures the entry's `discarded_at` before `undiscard!` and re-restores the videos with `discarded_at >= cutoff` (the cascade cohort) through `JournalEntryVideos::Restore` — videos removed individually *earlier* have a smaller `discarded_at` and stay removed. **Comments remain parent-only** (Phase 25 behaviour, unchanged) — images need nothing (they ride the surviving entry row).
- **Images detach without purge into a `DetachedAttachment`.** Active Storage has no native soft-delete and images have no per-item model. `JournalEntries::RemoveImage` creates a `DetachedAttachment` (blob_id + denormalised filename/type/size + actor) and calls **`attachment.delete`, not `destroy`** — `has_many_attached` defaults to `dependent: :purge_later`, so `destroy` would purge the blob (delete the file) the instant the job runs (i.e. in production). `delete` skips that callback. The record's *existence* is the "removed" state; `RestoreImage` re-attaches the retained blob and destroys the record. Both emit `detached_attachment.{removed,restored}`.
- **`OrphanBlobsCleanupJob` must skip retained image blobs.** A detached image blob has zero attachments, so the 24h orphan sweep would purge it — `app/jobs/orphan_blobs_cleanup_job.rb` excludes `DetachedAttachment.select(:blob_id)`. **This is the single load-bearing data-safety line; its spec is a merge gate.**
- **Feed wiring.** Image events use the **`detached_attachment` entity** (distinct from `journal_entry`) so the auditable is the per-item record the feed Restore keys on, not the entry. `AuditLog::Builder` gains `journal_entry_video_subject` + `detached_attachment_subject` (resolve trip/entry from payload sibling IDs, `with_discarded`); the `AuditLogSubscriber` filter lists the two new prefixes. `AuditLogsController#build_restorable` handles discard-based (`JournalEntryVideo`) and existence-based (`DetachedAttachment`) restorables; image restore is authorised through the parent entry's `restore?`. `JournalEntryVideoPolicy` (`destroy?`/`restore?`) mirrors the entry. Routes nested under journal_entries: `DELETE images/:signed_id` + `PATCH images/:detached_id/restore`, `DELETE videos/:id` + `PATCH videos/:id/restore`.
- **Remove UI.** Each photo tile / video player has an always-visible (not hover-only — a11y) Remove overlay gated on the entry's `destroy?`; `overflow-hidden` wraps only the image so the overlay isn't clipped.

---

## 5. Runtime Test Workflow (Mandatory)

After all code changes are committed and tests pass, you **must** perform a live runtime verification before pushing the branch or creating a PR.

### Steps

1. **Rebuild the app:**
   ```
   bin/cli app rebuild
   ```

2. **Restart the app:**
   ```
   bin/cli app restart
   ```

3. **Start the mail service:**
   ```
   bin/cli mail start
   ```

4. **Verify email delivery** at `https://mail.workeverywhere.docker/` using `agent-browser`.

5. **Visually verify the app** at `https://catalyst.workeverywhere.docker/` using `agent-browser`:
   - Home page renders correctly (logged out and logged in states).
   - Authentication flows work (create account, verify email, sign in, sign out).
   - All CRUD pages render and function (e.g., Users index, show, new, edit).
   - Account management pages render (show, edit).
   - Dark mode toggle works.
   - Flash messages (toasts) appear and dismiss.
   - Sidebar navigation links and active states are correct.

6. **Fix any runtime errors** found during live testing, commit the fix, and re-run the full test suite before pushing.

### Runtime Verification Scripts

When verifying server-side logic via `bin/rails runner` (e.g. MCP tools, service objects), build fixtures with **FactoryBot factories** rather than raw `Model.create!`:

```ruby
entry = FactoryBot.create(:journal_entry, trip: trip)
```

Raw `create!` silently misses required associations (e.g. `JournalEntry#author`, `Comment#user`), causing avoidable `RecordInvalid` failures and wasted rebuild/run cycles. Factories already encode every required association and a valid default state.

### Checklist

This checklist must be satisfied before pushing:

- [ ] `bin/cli app rebuild` succeeds
- [ ] `bin/cli app restart` health check passes
- [ ] `bin/cli mail start` is running
- [ ] Home page renders (logged out)
- [ ] Create account + email verification flow works
- [ ] Home page renders (logged in, with auth nav)
- [ ] Users CRUD pages render correctly
- [ ] Account page renders correctly
- [ ] Login page renders correctly
- [ ] Dark mode toggle works
- [ ] No runtime errors in any page

## Skill Self-Evaluation

After using any skill from this project, append a brief retrospective:

**Skill used**: [skill name]
**Step audit**:
- Any step that was redundant or unnecessary → note it
- Any step whose output was unused → note it
- Any command that produced an error or required a workaround → note it
- Any step where you deviated from the skill's instructions → explain why

**Improvement suggestion**: One concrete, actionable edit to the SKILL.md that would fix the most significant issue found. If none, write "No changes suggested."
