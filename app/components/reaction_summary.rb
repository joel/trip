# frozen_string_literal: true

module Components
  class ReactionSummary < Components::Base
    include Phlex::Rails::Helpers::ButtonTo

    EMOJIS = Reaction::ALLOWED_EMOJIS

    EMOJI_DISPLAY = {
      "thumbsup" => "\u{1F44D}",
      "heart" => "\u{2764}\u{FE0F}",
      "tada" => "\u{1F389}",
      "eyes" => "\u{1F440}",
      "fire" => "\u{1F525}",
      "rocket" => "\u{1F680}"
    }.freeze

    def initialize(trip:, journal_entry:)
      @trip = trip
      @entry = journal_entry
    end

    def view_template
      div(
        id: "reaction_summary_#{@entry.id}",
        class: "mt-6"
      ) do
        div(class: "flex flex-wrap items-center gap-2") do
          EMOJIS.each { |emoji| render_emoji_button(emoji) }
          render_total_count
        end
      end
    end

    private

    def render_emoji_button(emoji)
      count = reaction_counts[emoji] || 0
      active = user_reacted?(emoji)

      button_to(
        view_context.trip_journal_entry_reactions_path(
          @trip, @entry
        ),
        params: { emoji: emoji },
        class: active ? active_class : inactive_class,
        title: "#{EMOJI_DISPLAY[emoji]} #{emoji}",
        form: { class: "inline-flex" }
      ) do
        span { plain EMOJI_DISPLAY[emoji] }
        if count.positive?
          span(class: "ml-1 text-xs font-medium") do
            plain count.to_s
          end
        end
      end
    end

    def render_total_count
      total = reaction_counts.values.sum
      return unless total.positive?

      span(class: "ml-1 text-xs " \
                  "text-[var(--ha-on-surface-variant)]") do
        plain "#{total} reaction#{"s" if total != 1}"
      end
    end

    def reaction_counts
      @reaction_counts ||= @entry.reactions.group_by(&:emoji)
                                 .transform_values(&:size)
    end

    def user_reacted?(emoji)
      return false unless view_context.respond_to?(:current_user)

      current = view_context.current_user
      return false unless current

      @entry.reactions.any? do |r|
        r.user_id == current.id && r.emoji == emoji
      end
    end

    def active_class
      "inline-flex items-center rounded-full " \
        "bg-[var(--ha-primary-fixed)] " \
        "px-3 py-1 text-sm " \
        "transition-all duration-150 " \
        "ha-ghost-border"
    end

    def inactive_class
      "inline-flex items-center rounded-full " \
        "bg-[var(--ha-surface-muted)] " \
        "px-3 py-1 text-sm " \
        "transition-all duration-150 " \
        "ha-ghost-border " \
        "hover:bg-[var(--ha-surface-container)]"
    end
  end
end
