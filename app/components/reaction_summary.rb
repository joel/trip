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
        class: "ha-card p-4"
      ) do
        div(class: "flex flex-wrap gap-2") do
          EMOJIS.each { |emoji| render_emoji_button(emoji) }
        end
      end
    end

    private

    def render_emoji_button(emoji)
      count = reaction_counts[emoji] || 0
      active = user_reacted?(emoji)
      css = active ? active_class : inactive_class

      button_to(
        view_context.trip_journal_entry_reactions_path(
          @trip, @entry
        ),
        params: { emoji: emoji },
        class: css,
        form: { class: "inline-flex" }
      ) do
        span { EMOJI_DISPLAY[emoji] }
        span(class: "ml-1 text-xs") { count.to_s } if count.positive?
      end
    end

    def reaction_counts
      @reaction_counts ||= @entry.reactions.group(:emoji).count
    end

    def user_reacted?(emoji)
      return false unless view_context.respond_to?(:current_user)

      current = view_context.current_user
      return false unless current

      @entry.reactions.exists?(user: current, emoji: emoji)
    end

    def active_class
      "inline-flex items-center rounded-full border " \
        "border-[var(--ha-accent)]/30 bg-[var(--ha-accent)]/10 " \
        "px-3 py-1 text-sm transition-all duration-150"
    end

    def inactive_class
      "inline-flex items-center rounded-full border " \
        "border-[var(--ha-border)] bg-[var(--ha-surface)] " \
        "px-3 py-1 text-sm transition-all duration-150 " \
        "hover:bg-[var(--ha-surface-hover)]"
    end
  end
end
