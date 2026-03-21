# frozen_string_literal: true

module Components
  module Icons
    class Users < Components::Icons::Base
      def view_template
        svg(class: @css, **@attrs, viewBox: "0 0 20 20", fill: "none", aria_hidden: "true") do |s|
          s.path(
            d: "M6.5 14.5c.9-1.3 2.2-2 3.5-2s2.6.7 3.5 2",
            stroke: "currentColor",
            stroke_width: "1.5",
            stroke_linecap: "round"
          )
          s.circle(
            cx: "10",
            cy: "7",
            r: "3",
            stroke: "currentColor",
            stroke_width: "1.5"
          )
          s.rect(
            x: "3",
            y: "3",
            width: "14",
            height: "14",
            rx: "3",
            stroke: "currentColor",
            stroke_width: "1.5"
          )
        end
      end
    end
  end
end
