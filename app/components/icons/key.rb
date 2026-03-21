# frozen_string_literal: true

module Components
  module Icons
    class Key < Components::Icons::Base
      def view_template
        svg(class: @css, **@attrs, viewBox: "0 0 20 20", fill: "none", aria_hidden: "true") do |s|
          s.path(
            d: "M5 9.5c0-2.5 2-4.5 5-4.5s5 2 5 4.5-2 4.5-5 4.5S5 12 5 9.5z",
            stroke: "currentColor",
            stroke_width: "1.5"
          )
          s.path(
            d: "M10 7v5M7.5 9.5h5",
            stroke: "currentColor",
            stroke_width: "1.5",
            stroke_linecap: "round"
          )
        end
      end
    end
  end
end
