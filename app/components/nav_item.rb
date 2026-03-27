# frozen_string_literal: true

module Components
  class NavItem < Components::Base
    include Phlex::Rails::Helpers::LinkTo

    NAV_BASE = "ha-nav-item flex items-center gap-3 rounded-2xl px-4 py-3 text-sm " \
               "font-medium text-[var(--ha-on-surface-variant)] transition-all duration-300 " \
               "hover:text-[var(--ha-on-surface)] hover:bg-[var(--ha-on-surface)]/5"
    NAV_ACTIVE = "bg-[var(--ha-primary-container)]/10 text-[var(--ha-primary)]"

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
        render @icon
        span(class: "ha-nav-label") { @label }
      end
    end
  end
end
