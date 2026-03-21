# frozen_string_literal: true

module Components
  module Icons
    class ChevronLeft < Components::Icons::Base
      def view_template
        svg(class: @css, **@attrs, viewBox: "0 0 20 20", fill: "none", aria_hidden: "true") do |s|
          s.path(
            d: "M12 5l-5 5 5 5",
            stroke: "currentColor",
            stroke_width: "1.7",
            stroke_linecap: "round",
            stroke_linejoin: "round"
          )
        end
      end
    end
  end
end
