# frozen_string_literal: true

module Components
  module Icons
    class Person < Components::Icons::Base
      def view_template
        svg(class: @css, **@attrs, viewBox: "0 0 20 20", fill: "none", aria_hidden: "true") do |s|
          s.circle(
            cx: "10",
            cy: "7",
            r: "3",
            stroke: "currentColor",
            stroke_width: "1.5"
          )
          s.path(
            d: "M4.5 16.5c1-2.5 3.2-4 5.5-4s4.5 1.5 5.5 4",
            stroke: "currentColor",
            stroke_width: "1.5",
            stroke_linecap: "round"
          )
        end
      end
    end
  end
end
