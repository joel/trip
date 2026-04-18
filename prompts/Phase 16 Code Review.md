PR #103 Review Round 1 — Summary

  Fixes delivered (3 atomic commits)

  ┌─────────┬──────────────────────────────────────────────────────────────┬──────────┬───────────────────┐
  │ Commit  │                           Comment                            │ Severity │       File        │
  ├─────────┼──────────────────────────────────────────────────────────────┼──────────┼───────────────────┤
  │ 950cf27 │ Backfill duplicates before enforcing active-email uniqueness │ P1       │ migration         │
  ├─────────┼──────────────────────────────────────────────────────────────┼──────────┼───────────────────┤
  │ d6eb72f │ Scope registered-email validation to create operations       │ P2       │ access_request.rb │
  ├─────────┼──────────────────────────────────────────────────────────────┼──────────┼───────────────────┤
  │ bfa4ef6 │ Normalize email before checking active request conflicts     │ P2       │ access_request.rb │
  └─────────┴──────────────────────────────────────────────────────────────┴──────────┴───────────────────┘

  Verification

  - Migration dedupe: rolled back, seeded two active rows for the same email via insert_all!, re-ran db:migrate — older row transitioned to rejected, index created cleanly.
  - Validation scoping: two regression tests cover approve + reject after a User with the matching email exists.
  - Email normalisation: three tests cover downcasing-on-save, mixed-case duplicate, mixed-case existing-User match.
  - Suites: 585 non-system + 63 system = 648 examples, 0 failures. Lint clean.

  Governance

  - Replied to each of the 3 comments on PR #103 with the fix commit hash and explanation.
  - Resolved all 3 review threads via GraphQL resolveReviewThread.
  - Audit trail appended to prompts/Phase 16 - Steps.md in commit b6a23c8.

  Notes

  - Commit 950cf27 used SKIP=RailsSchemaUpToDate — the hook flagged a false positive because touching the migration changed its mtime, but the schema content was unchanged (same index, same version).
   The skip reason is documented in the commit body per AGENTS.md.