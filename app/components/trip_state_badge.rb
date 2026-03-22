# frozen_string_literal: true

module Components
  class TripStateBadge < Components::Base
    STATE_COLORS = {
      "planning" => "bg-sky-100 text-sky-800 " \
                    "dark:bg-sky-500/10 dark:text-sky-300",
      "started" => "bg-emerald-100 text-emerald-800 " \
                   "dark:bg-emerald-500/10 dark:text-emerald-300",
      "cancelled" => "bg-red-100 text-red-800 " \
                     "dark:bg-red-500/10 dark:text-red-300",
      "finished" => "bg-indigo-100 text-indigo-800 " \
                    "dark:bg-indigo-500/10 dark:text-indigo-300",
      "archived" => "bg-zinc-100 text-zinc-800 " \
                    "dark:bg-zinc-500/10 dark:text-zinc-300"
    }.freeze

    def initialize(state:)
      @state = state.to_s
    end

    def view_template
      css = STATE_COLORS[@state]
      span(
        class: "rounded-full px-3 py-1 text-xs font-medium #{css}"
      ) do
        plain @state.capitalize
      end
    end
  end
end
