# frozen_string_literal: true

module Components
  module Icons
    class Clock < Components::Icons::Base
      def view_template
        svg(class: @css, **@attrs, viewBox: "0 0 20 20", fill: "none",
            aria_hidden: "true") do |s|
          s.circle(
            cx: "10", cy: "10", r: "7.5",
            stroke: "currentColor", stroke_width: "1.5"
          )
          s.path(
            d: "M10 5.75V10l2.75 2.75",
            stroke: "currentColor", stroke_width: "1.5",
            stroke_linecap: "round", stroke_linejoin: "round"
          )
        end
      end
    end
  end
end
