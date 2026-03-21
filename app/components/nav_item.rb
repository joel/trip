# frozen_string_literal: true

module Components
  class NavItem < Components::Base
    include Phlex::Rails::Helpers::LinkTo

    NAV_BASE = "ha-nav-item flex items-center gap-3 rounded-2xl px-3 py-2.5 text-sm " \
               "font-medium text-[var(--ha-panel-muted)] transition hover:bg-white/10 " \
               "hover:text-[var(--ha-panel-text)]"
    NAV_ACTIVE = "bg-white/15 text-[var(--ha-panel-text)] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.08)]"

    def initialize(path:, label:, icon:, active: false, delay: "40ms")
      @path = path
      @label = label
      @icon = icon
      @active = active
      @delay = delay
    end

    def view_template
      css = "#{NAV_BASE} ha-rise"
      css = "#{css} #{NAV_ACTIVE}" if @active

      link_to(
        @path,
        class: css,
        style: "animation-delay: #{@delay};",
        aria: { current: (@active ? "page" : nil) }
      ) do
        span(class: "flex h-8 w-8 items-center justify-center rounded-xl bg-white/10") do
          render @icon
        end
        span(class: "ha-nav-label") { @label }
      end
    end
  end
end
