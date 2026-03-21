# frozen_string_literal: true

module Components
  module Icons
    class Plus < Components::Icons::Base
      def view_template
        svg(class: @css, **@attrs, viewBox: "0 0 20 20", fill: "none", aria_hidden: "true") do |s|
          s.path(
            d: "M10 5.5v9M5.5 10h9",
            stroke: "currentColor",
            stroke_width: "1.5",
            stroke_linecap: "round"
          )
        end
      end
    end
  end
end
