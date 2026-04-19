# Trip Journal — Project Summary

Bootstrap context for planning a new phase. Read this **instead of** `PRPs/trip-journal.md` + `CLAUDE.md` + `prompts/INITIAL Summary.md` (those three total ~2,300 lines; most of what's in them is irrelevant at planning time). Deeper references are called out section-by-section; only open them if your plan actually needs the detail.

---

## What the app is

Trip Journal is a **private, invite-only** collaborative trip journal. A small group (superadmins, contributors, viewers) plans trips, writes journal entries with rich text and photos, comments and reacts, and manages trip checklists. An AI assistant named **Jack** can operate on trips via an MCP endpoint — creating entries, toggling checklist items, etc. V1 is deployed as a PWA.

**Local URL:** `https://catalyst.workeverywhere.docker` · **Mail:** `https://mail.workeverywhere.docker` · **Repo:** [`joel/trip`](https://github.com/joel/trip) · **Kanban:** project `2` (owner `joel`).

---

## Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Language | **Ruby 4.0.1** | activated with `mise x --` in this project |
| Framework | **Rails 8.1.2** | Solid Queue / Cache / Cable, Propshaft, Importmap, Kamal deploy |
| DB | **SQLite** with **UUID PKs** | via `sqlite_crypto` fork; partial unique indexes supported |
| Auth | **Rodauth** + WebAuthn + email-auth + remember + Google OmniAuth | passwordless, invite-gated |
| Authorization | **ActionPolicy** | `authorize!` in controllers, `allowed_to?` in Phlex |
| Views | **Phlex** (no ERB except for Rodauth email templates) | auto-escaping; flag any new `unsafe_raw` |
| Client JS | **Hotwire** (Turbo + Stimulus) — importmap only, no npm | |
| CSS | **Tailwind CSS 4** with project design tokens (`--ha-*`) | dark mode class strategy |
| Rich text | **Action Text** (Trix today; Lexxy planned) | |
| Uploads | **Active Storage** — disk dev; SeaweedFS planned for prod (#44) | |
| Events | **Rails.event** structured subscribers | subscribers respond to `#emit(event)`, not `#call` |
| Actions | **Dry::Monads** `Success`/`Failure` | see `app/actions/CLAUDE.md` for the pattern |
| MCP | `mcp` gem at `POST /mcp`, 12 tools, API key via `MCP_API_KEY` | attributed to Jack |

---

## Domain (as of 2026-04-19)

All PKs are UUID. Models in production:

- **User** + `Roleable` concern — roles: `superadmin`, `admin`, `member`, `contributor`, `viewer`, `guest`. V1 uses `superadmin` / `contributor` / `viewer` (and `guest` as default).
- **AccessRequest**, **Invitation** — invite-only onboarding gate.
- **Trip** + **TripMembership** — trips have a state machine (`planning → started → finished → archived`; `cancelled` branches off), per-trip role (`contributor` / `viewer`), `start_date` / `end_date` can be explicit or derived from entries.
- **JournalEntry** — `has_rich_text :body`, `has_many_attached :images`, chronological index on `(trip_id, entry_date, created_at, id)`. Can be authored by a User or by Jack (actor_type/actor_id). Telegram idempotency via `(trip_id, telegram_message_id)` partial unique index.
- **Comment**, **Reaction** (polymorphic).
- **Checklist** → **ChecklistSection** → **ChecklistItem**.
- **Notification** + **JournalEntrySubscription** — in-app notification bell + follow-an-entry-for-new-comments.
- **Export** — Markdown + ePub, async via Active Job continuations.

Rodauth tables: `user_verification_keys`, `user_email_auth_keys`, `user_webauthn_keys`, `user_webauthn_user_ids`, `user_remember_keys`, `user_omniauth_identities`.

Canonical schema: `db/schema.rb`. Canonical policies: `app/policies/`.

---

## Planning-time conventions

The non-obvious ones that actually change how a plan is drafted:

- **Issue-first.** Every code change opens a GitHub issue before any implementation; see `/execution-plan`.
- **Atomic commits.** Never bundle multiple concerns. `#N <Capitalised action>` prefix when working a remediation round; Conventional-Commits-style `feat/fix/docs/refactor/test/chore(scope): subject` otherwise.
- **Phlex-first views.** New screens are Phlex classes under `app/views/` or `app/components/`. Use the design tokens (`--ha-*`) and the `ha-card` / `ha-button` / `ha-overline` etc. class families, not bespoke styles.
- **Actions layer.** New domain operations go through `app/actions/<domain>/<verb>.rb` (see `app/actions/CLAUDE.md`). Persist → emit event → return `Success(record)`. Controllers pattern-match on the result.
- **Rails.event subscribers.** Respond to `#emit(event)` where `event[:name]`, `event[:payload]`, `event[:tags]`. Register with `Rails.event.subscribe(subscriber)` in `config/initializers/event_subscribers.rb`, optional filter block.
- **Authorization is not query scoping.** Controllers use `Trip.find(params[:id])` + `authorize!(@trip)`. ActionPolicy enforces access. Don't flag unscoped finds as vulnerabilities unless `authorize!` is missing.
- **Test real user journeys.** Page rendering ≠ feature working. If the plan adds events, subscribers, or background jobs, the verification plan must cover downstream effects (email in MailCatcher, DB rows, job enqueue).
- **Live product verification is mandatory before PR.** `/product-review` runs `bin/cli app rebuild && app restart && mail start`, then walks every changed surface via `agent-browser`. Plans should explicitly name which pages need to be re-verified.
- **Tailwind JIT.** Any new Tailwind class needs a Docker rebuild (`bin/cli app rebuild`) — classes not already in the compiled CSS won't render. Prefer existing classes; if you must add, the plan should mention the rebuild.
- **overcommit enforces** trailing whitespace, no FIXME tokens, RuboCop, capitalised subjects, no trailing periods, text width (<60 char warning, <72 hard for body). If a hook is a genuine false positive, skip only that one (`SKIP=<HookName> git commit`) and document why in the commit body. Never `OVERCOMMIT_DISABLE=1`.
- **GitHub CLI:** always `unset GITHUB_TOKEN &&` before `gh` — keyring fallback fails otherwise.
- **Shell gotchas with docker exec + rails runner:** bang methods (`save!`, `find_by!`) break because bash consumes `!`. Use heredoc: `docker exec -i catalyst-app-dev bin/rails runner - < /tmp/script.rb`.
- **Rodauth form POSTs drop query params.** If the URL carries a token (e.g. `?invitation_token=xxx`), the form must carry it through with a hidden field. Pre-fill and lock fields whose value the system already knows (don't make the user retype an invitation email).

---

## Skills to reach for

| Situation | Skill |
|-----------|-------|
| Start end-to-end work from a plan (issue → branch → commit → PR) | `/execution-plan` |
| Remediate a batch of findings from a review on the current branch | `/qa-remediation` |
| Mandatory pre-PR live verification (rebuild + browser walk) | `/product-review` |
| Adversarial QA — break the feature | `/qa-review` |
| Security / vulnerability pass | `/security-review` |
| Flow, accessibility, mobile | `/ux-review` |
| Visual polish (composition, typography, viewport) | `/ui-polish` |
| Design-system compliance + UI library sync | `/ui-designer` |
| New PRP from scratch | `/generate-prp` |
| MCP endpoint operations as Jack | `/trip-journal-mcp` |

---

## Where to look if the plan needs deeper context

| You need | Open |
|----------|------|
| Full V1 audit / original data model / role matrix | `PRPs/trip-journal.md` (1,500 lines — only if genuinely needed) |
| Targeted feature PRP (one per feature) | `PRPs/<feature>.md` |
| The plan for a specific past phase | `prompts/Phase N <title>.md` |
| What actually happened in a phase (audit trail) | `prompts/Phase N - Steps.md` |
| Deep-QA reports for a phase | `prompts/Phase X - {QA,Security,UX,UI Polish,UI Designer} Review.md` |
| UI component catalogue (Phlex + tokens) | `ui_library/README.md` + `ui_library/<component>.yml` |
| Action pattern + event names inventory | `app/actions/CLAUDE.md` |
| Available CLI commands | `bin/cli tree` / `bin/cli help` |
| Current schema | `db/schema.rb` |
| Current policies (source of truth for authorization) | `app/policies/` |
| Current routes | `config/routes.rb` |

---

## How to check live project state

Not baked into this file — it goes stale fast. Run these instead:

```bash
git status && git log --oneline -10            # where the branch is
unset GITHUB_TOKEN && gh pr list --state open   # PRs in flight
unset GITHUB_TOKEN && gh issue list --state open --limit 30  # backlog
```

---

## History at a glance

V1 scope is carried out through a numbered **phase** sequence. Each phase has a plan (`prompts/Phase N *.md`) and an audit trail (`prompts/Phase N - Steps.md`). The full list from `prompts/` tells you what's been done. At the time of writing, the most recent completed phase is **Phase 16 — Onboarding Improvements** (PR #103). Phase-17+ work lives in open GitHub issues (notably #110 security enumeration, #111 onboarding UX follow-ups, #44 SeaweedFS, plus various feed-wall / remember / notification issues).
