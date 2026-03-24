# frozen_string_literal: true

module Components
  class PwaInstallBanner < Components::Base
    def view_template
      div(
        data: { controller: "pwa" },
        class: "fixed bottom-6 right-6 z-50"
      ) do
        div(
          data: { pwa_target: "banner" },
          class: "hidden pointer-events-auto flex items-start gap-3 rounded-2xl " \
                 "border border-sky-300/30 " \
                 "bg-[linear-gradient(140deg,rgba(56,189,248,0.12),rgba(15,23,42,0.92))] " \
                 "p-4 text-sky-100 " \
                 "shadow-[0_18px_45px_-30px_rgba(56,189,248,0.6)] " \
                 "transition-all duration-300 ease-out max-w-sm"
        ) do
          render_icon
          render_content
          render_dismiss_button
        end
      end
    end

    private

    def render_icon
      div(class: "flex h-9 w-9 flex-shrink-0 items-center justify-center " \
                 "rounded-xl bg-sky-400/20 text-sky-200") do
        svg(
          class: "h-5 w-5",
          viewBox: "0 0 20 20",
          fill: "none",
          aria_hidden: "true"
        ) do |s|
          s.path(
            d: "M10 3v10m0 0l-3-3m3 3l3-3M4 15h12",
            stroke: "currentColor",
            stroke_width: "1.6",
            stroke_linecap: "round",
            stroke_linejoin: "round"
          )
        end
      end
    end

    def render_content
      div(class: "min-w-0 flex-1") do
        p(class: "text-sm font-semibold") { "Install Trip Journal" }
        p(class: "mt-1 text-sm text-sky-100/80") do
          "Add to your home screen for quick access."
        end
        button(
          type: "button",
          data: { action: "pwa#install" },
          class: "mt-2 inline-flex items-center rounded-lg bg-sky-500/20 px-3 py-1.5 " \
                 "text-xs font-medium text-sky-100 transition hover:bg-sky-500/30"
        ) { "Install" }
      end
    end

    def render_dismiss_button
      button(
        type: "button",
        data: { action: "pwa#dismiss" },
        class: "flex h-7 w-7 items-center justify-center rounded-full " \
               "text-sky-100/80 transition hover:bg-sky-200/10 hover:text-sky-100",
        aria_label: "Dismiss"
      ) do
        render Components::Icons::Close.new(css: "h-3.5 w-3.5")
      end
    end
  end
end
