Consolidated Review Summary — Phase 9

  Critical / Must Fix

  ┌─────┬─────────────────────────────────────┬────────────┬──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  #  │               Finding               │   Source   │                                                             Description                                                              │
  ├─────┼─────────────────────────────────────┼────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ D1  │ JournalEntryPolicy superadmin state │ QA +       │ The exact same superadmin? || (condition && state_check) bug fixed in 4 policies was missed in JournalEntryPolicy. Superadmin can    │
  │     │  bypass NOT fixed                   │ Security   │ create/edit/delete journal entries on finished/cancelled/archived trips. Same bug class as GitHub #21.                               │
  └─────┴─────────────────────────────────────┴────────────┴──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

  Friction / Should Fix

  ┌─────┬────────────────────────────────────────────────────────────────────────────┬────────────────┬─────────────────┐
  │  #  │                                  Finding                                   │     Source     │    Severity     │
  ├─────┼────────────────────────────────────────────────────────────────────────────┼────────────────┼─────────────────┤
  │ F1  │ No Cancel button on comment edit form                                      │ UX + UI Polish │ Medium          │
  ├─────┼────────────────────────────────────────────────────────────────────────────┼────────────────┼─────────────────┤
  │ F2  │ Validation errors cause full-page redirect (loses scroll position)         │ UX             │ Medium          │
  ├─────┼────────────────────────────────────────────────────────────────────────────┼────────────────┼─────────────────┤
  │ F3  │ Edit textarea lacks accessible label + duplicate id with multiple comments │ UX             │ Low             │
  ├─────┼────────────────────────────────────────────────────────────────────────────┼────────────────┼─────────────────┤
  │ F4  │ "Edit" summary hover has no transition-colors (hard snap)                  │ UI Polish      │ Low (one-liner) │
  ├─────┼────────────────────────────────────────────────────────────────────────────┼────────────────┼─────────────────┤
  │ F5  │ list-none class on summary is redundant/not in compiled CSS                │ UI Designer    │ Low (one-liner) │
  ├─────┼────────────────────────────────────────────────────────────────────────────┼────────────────┼─────────────────┤
  │ F6  │ ui_library/comment_card.yml out of sync with new edit form                 │ UI Designer    │ Low             │
  └─────┴────────────────────────────────────────────────────────────────────────────┴────────────────┴─────────────────┘

  Warnings (conscious acceptance)

  ┌─────┬───────────────────────────────────────────────────────────────┬──────────┐
  │  #  │                            Finding                            │  Source  │
  ├─────┼───────────────────────────────────────────────────────────────┼──────────┤
  │ W1  │ No rate limiting on /mcp endpoint (pre-existing)              │ Security │
  ├─────┼───────────────────────────────────────────────────────────────┼──────────┤
  │ W2  │ Jack user auto-creation via find_or_create_by! at runtime     │ Security │
  ├─────┼───────────────────────────────────────────────────────────────┼──────────┤
  │ W3  │ ExportPolicy#show? doesn't enforce state check for superadmin │ Security │
  └─────┴───────────────────────────────────────────────────────────────┴──────────┘

  ---
  The one critical finding (D1) must be fixed before merge. Want me to fix the JournalEntryPolicy now?