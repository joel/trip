# Phase 19 — Steps (audit trail)

> Append-only log of decisions, commits, and verifications.
> Plan: [`prompts/Phase 19 - Agent Identity - Phase 1 - PRP.md`](Phase%2019%20-%20Agent%20Identity%20-%20Phase%201%20-%20PRP.md).
> Brainstorm: [`prompts/Phase 19 - Agent Identity Brainstorming.md`](Phase%2019%20-%20Agent%20Identity%20Brainstorming.md).

---

## 1. Issue + plan

- **Issue:** [#116 — Phase 19 Phase 1 — Agent Identity (Registered Agents)](https://github.com/joel/trip/issues/116) (label: `enhancement`).
- **Plan:** `prompts/Phase 19 - Agent Identity - Phase 1 - PRP.md`.
- **User approved the plan.**

## 1a. Kanban

- **Blocked on scope:** `gh auth` keyring token is missing `read:project` / `write:project`. Kanban card transitions (Backlog → Ready → In Progress → In Review → Done) must be done manually this phase, or after `gh auth refresh -s read:project,project`.

## 2. Branch

- `feature/phase19-agent-identity` (off `main`).

## 3. Commits

1. `10cf542` — Introduce Agent model + migrations + specs + `:system_actor` user factory trait + Phase 19 Steps.md.
2. `aac8f83` — Wire agent identity through MCP stack: controller reads `X-Agent-Identifier`, server templates instructions, base_tool exposes `resolve_agent_user`, write-path tools pipe server_context through, Phase 1.5 cleanup drops `actor_type`/`actor_id` params + `VALID_ACTOR_TYPES`. Specs updated.
3. `09d192a` — Seed Marée system user and both Agent records (idempotent).
4. `85b1c1f` — Update MCP docs across AGENTS.md, README.md, app/mcp/README.md, curl cheatsheet, and the trip-journal-mcp skill; drop `actor_type`/`actor_id` and Jack-as-sole-actor language.

## 4. Runtime verification

- `bin/cli app rebuild` → container up, `GET /up` returns 200.
- `mise x -- bundle exec rake project:lint` → clean (436 files, 0 offenses).
- `mise x -- bundle exec rake project:tests` → 636 examples, 0 failures, 2 pending (pre-existing).
- `mise x -- bundle exec rake project:system-tests` → 78 examples, 0 failures.
- **curl smoke tests against `https://catalyst.workeverywhere.docker/mcp`:**
  - No `X-Agent-Identifier` header → JSON-RPC `-32001`, message *"Missing X-Agent-Identifier header…"*.
  - `X-Agent-Identifier: jack` → 12 tools returned.
  - `X-Agent-Identifier: ghost` → JSON-RPC `-32001`, message *"Agent 'ghost' is not registered…"*.
  - `X-Agent-Identifier: maree` + `initialize` → instructions begin *"You are Marée, an AI travel assistant for the Trip Journal app…"*.
- **End-to-end attribution**: `create_journal_entry` with `X-Agent-Identifier: maree` → new `JournalEntry#author` is `Marée <maree@system.local>`, not Jack.
- **Browser sweep**: `https://catalyst.workeverywhere.docker/` home page renders cleanly (screenshot `tmp/phase19/01_home.png`). Phase 1 has no UI surface; the render check confirms the Agent autoload + migration didn't break the boot path.

## 5. PR + review

_TBD_

## 6. Final summary

_TBD_
