# frozen_string_literal: true

# Version the rich-text *content* of journal entries.
#
# JournalEntry#body is `has_rich_text :body` — a separate ActionText::RichText
# row, not a column on journal_entries. paper_trail on JournalEntry alone would
# version the title (`name`) but never the body. Enabling paper_trail on
# ActionText::RichText captures every body edit as a revertible version.
#
# Only the journal entry body uses rich text in this app (trip/comment bodies
# are plain text), so this is narrowly scoped in practice. The version inherits
# the same PaperTrail.request.whodunnit as the parent write, because Action Text
# saves the rich text inside the parent's save (same request block).
ActiveSupport.on_load(:action_text_rich_text) do
  include PaperTrail::Model

  has_paper_trail on: %i[create update]
end
