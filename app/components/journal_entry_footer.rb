# frozen_string_literal: true

module Components
  class JournalEntryFooter < Components::Base
    REACTION_EMOJI = Components::ReactionSummary::EMOJI_DISPLAY

    def initialize(journal_entry:)
      @entry = journal_entry
    end

    def view_template
      div(class: "mt-4 pt-4 flex items-center " \
                 "justify-between border-t " \
                 "border-[var(--ha-surface-high)]") do
        render_stats
        render_toggle
      end
    end

    private

    def render_stats
      div(class: "flex items-center gap-3 text-xs " \
                 "text-[var(--ha-on-surface-variant)]") do
        render_reaction_pills
        render_comment_count
      end
    end

    def render_reaction_pills
      counts = @entry.reactions.group(:emoji).count
      return if counts.empty?

      div(
        id: "reaction_count_#{@entry.id}",
        class: "flex items-center gap-1"
      ) do
        counts.first(3).to_h.each_key do |emoji|
          display = REACTION_EMOJI[emoji]
          next unless display

          span(class: "text-sm") { plain display }
        end
        total = counts.values.sum
        span(class: "ml-1") { plain total.to_s }
      end
    end

    def render_comment_count
      count = @entry.comments.count
      return unless count.positive?

      span(class: "inline-flex items-center gap-1") do
        plain "\u{1F4AC}"
        plain "#{count} comment#{"s" if count != 1}"
      end
    end

    def render_toggle
      button(
        class: "inline-flex items-center gap-1 text-sm " \
               "font-semibold text-[var(--ha-primary)] " \
               "cursor-pointer hover:gap-2 " \
               "transition-all duration-200",
        data: { action: "feed-entry#toggle" }
      ) do
        span(data: { feed_entry_target: "label" }) do
          plain "Read more"
        end
        plain " \u25BE"
      end
    end
  end
end
