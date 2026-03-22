# frozen_string_literal: true

module Components
  module Icons
    class Map < Components::Icons::Base
      def view_template
        svg(class: @css, **@attrs, viewBox: "0 0 20 20",
            fill: "none", aria_hidden: "true") do |s|
          s.path(
            d: "M3 5.5l5-2 4 2 5-2v11l-5 2-4-2-5 2V5.5z",
            stroke: "currentColor",
            stroke_width: "1.5",
            stroke_linejoin: "round"
          )
          s.path(
            d: "M8 3.5v11M12 5.5v11",
            stroke: "currentColor",
            stroke_width: "1.5"
          )
        end
      end
    end
  end
end
