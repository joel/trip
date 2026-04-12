# Prompt

I have Claude Code, and I want to ensure that the skills I use are the most efficient. To achieve this, I want to do two things:

# Audit and one-shot improvement

First, I would like to conduct an audit of the skill. I need feedback from the model to see how it can be improved. I'm also concerned that the skill adheres to the open standard outlined at https://agentskills.io/.

# Self-improvement over time

Additionally, I want the model not just to use the skills, but to evaluate them while using them. This way, it can provide self-improvement recommendations after each use.

For example, if the skill suggests a command, I want feedback on whether that command is redundant, unhelpful, counterintuitive, or if there are any other relevant observations. I would like the model to provide remediation and improvement suggestions.

I'm wondering if the self-improvement aspect should be a separate skill or if it should be included as prompt instructions given alongside the other instructions.

# How

Knowing the skills I'm talking about live in the project itself. What would be the best way to talk about those 2 tasks?

# Reply from Sonnet 4.6

Good news: you already have the right tool — the `skill-creator` skill. But the two tasks have meaningfully different shapes, and the answer to your self-improvement question is nuanced. Let me break it down.

---

## Task 1: Audit + One-Shot Improvement

**Best approach: Claude Code session with skill-creator**

Since your skills live in the project, Claude Code has direct filesystem access to them. The cleanest workflow is:

1. Open your project in Claude Code
2. Point Claude at the skill-creator skill and say something like: *"Audit all my skills in `[path]` against the agentskills.io specification and suggest improvements for each."*

Claude Code will read each `SKILL.md`, check it against the spec (frontmatter structure, description quality, progressive disclosure, the `<500 lines` guideline, bundled resources organization, etc.) and propose edits inline. The skill-creator skill already has guidance for exactly this — it handles the case where a draft already exists and skips straight to the iterate phase.

For the agentskills.io spec check specifically, the key things it will audit against are:
- Required YAML frontmatter (`name`, `description`)
- Description quality (triggering specificity — the spec warns Claude tends to *undertrigger*, so descriptions should be slightly "pushy")
- Progressive disclosure (metadata → body → bundled resources)
- Body length discipline (<500 lines)
- Reference file organization

---

## Task 2: Self-Improvement Over Time

**Answer: `CLAUDE.md` project instructions, not a separate skill**

Here's the reasoning:

A **separate skill** for self-evaluation would need to trigger *after* every other skill — but skill triggering is based on the task description, not on what just happened. You'd end up with a skill that either never triggers reliably or requires the user to explicitly invoke it, defeating the "automatic" goal.

**Project-level `CLAUDE.md` instructions** are always in context and apply universally to every Claude Code session in that project. This is exactly the right layer for behavioral modifiers (vs. skills, which are capability packages).

A `CLAUDE.md` entry like this would work well:

```markdown
## Skill Self-Evaluation

After using any skill from this project, append a brief retrospective:

**Skill used**: [skill name]
**Step audit**:
- Any step that was redundant or unnecessary → note it
- Any step whose output was unused → note it
- Any command that produced an error or required a workaround → note it
- Any step where you deviated from the skill's instructions → explain why

**Improvement suggestion**: One concrete, actionable edit to the SKILL.md that would fix the most significant issue found. If none, write "No changes suggested."
```

This way every skill use automatically generates a small diff log. Over time, patterns emerge — and you (or Claude) can batch those into actual edits using the skill-creator.

---

## Summary

| Task | Where to do it | Tool |
|---|---|---|
| One-shot audit | Claude Code session | `skill-creator` skill |
| agentskills.io compliance check | Same session | `skill-creator` + fetch the spec |
| Ongoing self-improvement | `CLAUDE.md` in your project | Plain instructions (not a skill) |

Want me to draft the `CLAUDE.md` self-evaluation block in more detail, or sketch out the audit prompt you'd use to kick off the Claude Code session?

# In the project with Claude Code

Audit all my skills in [.claude/skills/] against the agentskills.io specification and suggest improvements for each. Do it one by one. After each, stop, provide the suggestions, and ask

 # Batch A (size-fix, pure progressive disclosure):
  - Split product-review — move Steps 15/16/17 + Bullet audit to references/. Biggest win.
  - Split qa-review — move MCP + Mobile sections to references/. Smaller but same pattern.

Batch A done.

  ┌────────────────┬────────┬───────┬─────────────┐
  │     Skill      │ Before │ After │      Δ      │
  ├────────────────┼────────┼───────┼─────────────┤
  │ product-review │    678 │   392 │ −286 (−42%) │
  ├────────────────┼────────┼───────┼─────────────┤
  │ qa-review      │    516 │   328 │ −188 (−36%) │
  └────────────────┴────────┴───────┴─────────────┘

  6 new reference files:
  - product-review/references/: bullet_audit.md (54), pwa_verification.md (73), mcp_verification.md (85), mobile_verification.md (95)
  - qa-review/references/: mcp_edge_cases.md (123), mobile_testing.md (75)

  Each moved section in SKILL.md now has a 4–6 line pointer that names the trigger condition ("For any PR that touches service workers, JavaScript, Turbo…"), so progressive disclosure actually
  disclosed — the agent only loads the reference when the PR warrants it.

  Both skills comfortably under the 500-line recommendation. grep confirms all 4 pointers land in product-review (lines 287, 310, 316, 322) and both land in qa-review (lines 206, 212).

  ---
  Governance question

  These are uncommitted changes in the project repo. Your CLAUDE.md and governance-workflow memory say every code change gets an issue → Kanban → branch → PR, but also says skill files can use [skip
  ci]. I haven't committed anything yet.

  How do you want to handle this?

  1. Full governance — I create a cleanup issue, move it through Kanban, branch off, commit both refactors (probably two atomic commits), PR, review.
  2. Lightweight — feature branch + PR but skip the issue/Kanban ceremony since it's docs/config.
  3. Direct commit to main — two atomic commits with [skip ci], no PR. Fastest.
  4. Leave uncommitted — you'll handle it yourself.

  I'd lean 1 given your memory explicitly flags that you corrected me for skipping governance before, but options 2 and 3 are legit for pure skill refactors. Your call.

  Skill used: skill-creator
  Step audit: Used the audit reference workflow to identify the split points, then applied the same progressive-disclosure pattern I used earlier for skill-creator itself. No deviations; no redundant
   steps. The one thing worth flagging: I reused the same "short pointer + conditional loading phrase" pattern for all 6 sections, which risks being formulaic. In practice the trigger conditions are
  genuinely different (PWA/MCP/Mobile each have distinct "when does this apply"), so the repetition is informative, not lazy.

  Improvement suggestion: No changes suggested to skill-creator itself. The workflow held up for a refactor-at-scale task (6 extractions across 2 skills) without any gaps.


# Batch B (portability and dedupe):

  - Add compatibility field to ui-designer, delete the stale component inventory, move the library index table to references/component_library.md.
  - Decide about global frontend-design vs project ui-designer (delete one, or diverge the global one).
  - Move or delete ui-polish-workspace/.

  Want me to do Batch A first, Batch B, both, or pick a different subset?

  Skill used: skill-creator
  Step audit: Used the references/auditing.md workflow I created earlier — and it was actually useful this time. Inventoried → ran the spec checklist → read each skill → clustered findings by
  severity → presented decision points. No redundant steps; the checklist structure kept me from wandering.

  Improvement suggestion: references/auditing.md could add one item to the "When to recommend deletion vs rewrite vs move" section: "When two skills (one global, one project-local) overlap in
  purpose, prefer deleting the one whose content is tied to a specific project." That exact pattern came up with frontend-design vs ui-designer and the current reference doesn't name it.

 Batch B done.

  Final state

  ┌─────────────────────────────────────────────┬─────────┬──────────┬─────────────┐
  │                   Change                    │ Before  │  After   │      Δ      │
  ├─────────────────────────────────────────────┼─────────┼──────────┼─────────────┤
  │ ui-designer/SKILL.md                        │     263 │      146 │ −117 (−44%) │
  ├─────────────────────────────────────────────┼─────────┼──────────┼─────────────┤
  │ ui-designer/references/component_library.md │       — │ 79 (new) │           — │
  ├─────────────────────────────────────────────┼─────────┼──────────┼─────────────┤
  │ Global ~/.claude/skills/frontend-design/    │ present │  deleted │           — │
  ├─────────────────────────────────────────────┼─────────┼──────────┼─────────────┤
  │ .claude/skills/ui-polish-workspace/         │ present │  deleted │           — │
  └─────────────────────────────────────────────┴─────────┴──────────┴─────────────┘

  What changed in ui-designer

  - Added compatibility field naming the Rails + Phlex + Tailwind standalone + Hotwire stack and the two external dependencies (Tailwind UI library path + project-local ui_library/*.yml registry).
  - Moved the full UI Components Library section — library structure table, usage workflow, Phlex translation example, browsing/regeneration commands — to references/component_library.md. The in-body
   replacement is a 4-line pointer that still gives the agent enough context to decide whether to load the reference.
  - Replaced the stale 35-row "Existing Project Components" table with a 2-line instruction to run ls app/components/*.rb. The table was project state masquerading as skill knowledge and was already
  behind.
  - All the actually-valuable content stays inline: stack constraints, ui_library/*.yml registry explanation, CSS tokens, component classes, Tailwind JIT constraint, Phlex view structure, workflow
  steps.

  Cleanup

  - Global frontend-design skill fully removed from ~/.claude/skills/ — ui-designer now the single source of truth for frontend work. (Runtime skill list still caches the name until next session.)
  - ui-polish-workspace/ eval leftovers removed from .claude/skills/. Project skills directory now contains only the 8 legitimate skill directories.

  Memory update

  Updated feedback_governance_workflow.md with a scope exclusion: skill file refactors, slash commands, and Claude config changes are NOT "code changes" and skip the full Kanban/PR workflow. Future
  me won't re-ask this question.

  ---
  All 4 audit batches summary

  Everything you authorized across the session:

  ┌─────┬──────────────────────────────────────────────────────────────────┬──────────────────────────────────────────────┐
  │  #  │                              Action                              │                   Outcome                    │
  ├─────┼──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤
  │ 1   │ Move global pr-summary to ~/.claude/commands/                    │ Done                                         │
  ├─────┼──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤
  │ 2   │ Refactor global skill-creator (license + progressive disclosure) │ 485 → 468 lines, 4 reference files           │
  ├─────┼──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤
  │ 3   │ Add audit workflow to skill-creator                              │ references/auditing.md added                 │
  ├─────┼──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤
  │ 4   │ Fix global frontend-design portability                           │ Done — then superseded by deletion in step 9 │
  ├─────┼──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤
  │ 5   │ Delete global explain-code                                       │ Done                                         │
  ├─────┼──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤
  │ 6   │ Audit project-local skills                                       │ 2 hard findings + several best-practice gaps │
  ├─────┼──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤
  │ 7   │ Batch A: split product-review                                    │ 678 → 392 lines, 4 reference files           │
  ├─────┼──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤
  │ 8   │ Batch A: split qa-review                                         │ 516 → 328 lines, 2 reference files           │
  ├─────┼──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤
  │ 9   │ Batch B: refactor ui-designer                                    │ 263 → 146 lines, 1 reference file            │
  ├─────┼──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤
  │ 10  │ Batch B: delete global frontend-design (duplicate)               │ Done                                         │
  ├─────┼──────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────┤
  │ 11  │ Batch B: delete ui-polish-workspace/ clutter                     │ Done                                         │
  └─────┴──────────────────────────────────────────────────────────────────┴──────────────────────────────────────────────┘

  Global skills now: agent-browser, find-skills, skill-creator, plus the pr-summary command. Project skills: all 8 compliant, average ~200 lines, proper references/ usage where it earns its keep.

  Uncommitted changes in the catalyst repo; handle as you see fit.

  Skill used: skill-creator
  Step audit: Same progressive-disclosure pattern as all prior batches — write reference, replace inline with pointer, delete stale content. No deviations, no errors. The three-Edit sequence on a
  single file went cleanly because I re-read targeted ranges just before editing, avoiding stale line-number assumptions.

  Improvement suggestion: One real gap surfaced in this batch that's worth adding to references/auditing.md: stale inventory smell — when an audit finds a table or list that's really project state
  rather than skill knowledge (file listings, component registries, gem lists), default to replacing it with the command that regenerates the state (ls, grep, bundle info) rather than trying to keep
  the list current. This came up twice in the project audit (component inventory in ui-designer, and arguably the seed-data tables in product-review/qa-review) and it's a pattern worth naming
  explicitly.

Improvement suggestion:

references/auditing.md could add one item to the "When to recommend deletion vs rewrite vs move"
section: "When two skills (one global, one project-local) overlap in
  purpose, prefer deleting the one whose content is tied to a specific project."

That exact pattern came up with frontend-design vs ui-designer and the current reference doesn't name it.

Let's remove the global skill `frontend-design` for now, I don't want the model to get confused.

