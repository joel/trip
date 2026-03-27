# frozen_string_literal: true

module Components
  module Icons
    class Bell < Components::Icons::Base
      def view_template
        svg(class: @css, **@attrs, viewBox: "0 0 20 20", fill: "none", aria_hidden: "true") do |s|
          s.path(
            d: "M10 2.5a4.5 4.5 0 0 0-4.5 4.5v3.17l-1.32 1.98A.75.75 0 0 0 4.8 13.5h10.4" \
               "a.75.75 0 0 0 .62-1.35L14.5 10.17V7A4.5 4.5 0 0 0 10 2.5z",
            stroke: "currentColor",
            stroke_width: "1.5",
            stroke_linejoin: "round"
          )
          s.path(
            d: "M8 13.5v.5a2 2 0 0 0 4 0v-.5",
            stroke: "currentColor",
            stroke_width: "1.5",
            stroke_linecap: "round"
          )
        end
      end
    end
  end
end
