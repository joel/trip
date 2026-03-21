# frozen_string_literal: true

module Components
  module Icons
    class SignIn < Components::Icons::Base
      def view_template
        svg(class: @css, **@attrs, viewBox: "0 0 20 20", fill: "none", aria_hidden: "true") do |s|
          s.path(
            d: "M7 5h6a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H7",
            stroke: "currentColor",
            stroke_width: "1.5",
            stroke_linecap: "round"
          )
          s.path(
            d: "M12.5 10H4M7.5 6.5 4 10l3.5 3.5",
            stroke: "currentColor",
            stroke_width: "1.5",
            stroke_linecap: "round",
            stroke_linejoin: "round"
          )
        end
      end
    end
  end
end
