# frozen_string_literal: true

module Components
  module Icons
    class Home < Components::Icons::Base
      def view_template
        svg(class: @css, **@attrs, viewBox: "0 0 20 20", fill: "none", aria_hidden: "true") do |s|
          s.path(
            d: "M3 9.5L10 4l7 5.5V16a1 1 0 0 1-1 1h-4v-5H8v5H4a1 1 0 0 1-1-1V9.5z",
            stroke: "currentColor",
            stroke_width: "1.5",
            stroke_linejoin: "round"
          )
        end
      end
    end
  end
end
