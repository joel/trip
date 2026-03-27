# frozen_string_literal: true

module Components
  class TripStateBadge < Components::Base
    STATE_COLORS = {
      "planning" => "bg-[var(--ha-primary-container)]/20 " \
                    "text-[var(--ha-on-primary-container)]",
      "started" => "bg-[var(--ha-secondary-container)] " \
                   "text-[var(--ha-on-secondary-container)]",
      "cancelled" => "bg-[var(--ha-error-container)] " \
                     "text-[var(--ha-error)]",
      "finished" => "bg-[var(--ha-surface-variant)] " \
                    "text-[var(--ha-on-surface-variant)]",
      "archived" => "bg-[var(--ha-surface-high)] " \
                    "text-[var(--ha-on-surface-variant)]"
    }.freeze

    def initialize(state:)
      @state = state.to_s
    end

    def view_template
      css = STATE_COLORS.fetch(@state, STATE_COLORS["planning"])
      span(
        class: "inline-flex items-center rounded-full px-3 py-1 " \
               "text-[10px] font-bold uppercase tracking-widest #{css}"
      ) do
        plain @state.capitalize
      end
    end
  end
end
