# frozen_string_literal: true

module Components
  class ExportStatusBadge < Components::Base
    STATUS_COLORS = {
      "pending" => "bg-amber-100 text-amber-800 " \
                   "dark:bg-amber-500/10 dark:text-amber-300",
      "processing" => "bg-sky-100 text-sky-800 " \
                      "dark:bg-sky-500/10 dark:text-sky-300 " \
                      "animate-pulse",
      "completed" => "bg-emerald-100 text-emerald-800 " \
                     "dark:bg-emerald-500/10 dark:text-emerald-300",
      "failed" => "bg-red-100 text-red-800 " \
                  "dark:bg-red-500/10 dark:text-red-300"
    }.freeze

    def initialize(status:)
      @status = status.to_s
    end

    def view_template
      css = STATUS_COLORS[@status]
      span(
        class: "rounded-full px-3 py-1 text-xs font-medium #{css}"
      ) do
        plain @status.capitalize
      end
    end
  end
end
