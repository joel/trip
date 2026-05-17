# frozen_string_literal: true

module Components
  # The full-screen viewer chrome. Rendered once inside any element that
  # carries `data-controller="lightbox"` (the JournalEntryCard article or
  # the Gallery wrapper). Behaviour lives in lightbox_controller.js; this
  # component is pure markup + Stimulus targets.
  class LightboxOverlay < Components::Base
    def view_template
      div(
        hidden: true,
        role: "dialog",
        aria_modal: "true",
        aria_label: "Image viewer",
        class: "fixed inset-0 z-50 flex items-center justify-center " \
               "bg-black/90 backdrop-blur-sm",
        data: {
          lightbox_target: "overlay",
          action: "click->lightbox#backdrop " \
                  "touchstart->lightbox#touchStart " \
                  "touchend->lightbox#touchEnd"
        }
      ) do
        render_close
        render_prev
        render_image
        render_next
        render_counter
        render_caption
      end
    end

    private

    def render_close
      button(
        type: "button",
        aria_label: "Close image viewer",
        class: "absolute top-4 right-4 flex h-11 w-11 items-center " \
               "justify-center rounded-full bg-white/10 text-white " \
               "transition hover:bg-white/20 focus:outline-none " \
               "focus-visible:ring-2 focus-visible:ring-white",
        data: { lightbox_close: "", action: "lightbox#close" }
      ) do
        render Components::Icons::Close.new(css: "h-6 w-6")
      end
    end

    def render_prev
      button(
        type: "button",
        aria_label: "Previous image",
        class: "absolute left-2 sm:left-4 flex h-12 w-12 items-center " \
               "justify-center rounded-full bg-white/10 text-white " \
               "transition hover:bg-white/20 focus:outline-none " \
               "focus-visible:ring-2 focus-visible:ring-white",
        data: { lightbox_target: "nav", action: "lightbox#prev" }
      ) do
        render Components::Icons::ChevronLeft.new(css: "h-7 w-7")
      end
    end

    def render_next
      button(
        type: "button",
        aria_label: "Next image",
        class: "absolute right-2 sm:right-4 flex h-12 w-12 items-center " \
               "justify-center rounded-full bg-white/10 text-white " \
               "transition hover:bg-white/20 focus:outline-none " \
               "focus-visible:ring-2 focus-visible:ring-white",
        data: { lightbox_target: "nav", action: "lightbox#next" }
      ) do
        render Components::Icons::ChevronLeft.new(
          css: "h-7 w-7 rotate-180"
        )
      end
    end

    def render_image
      img(
        src: "",
        alt: "",
        class: "max-h-[90vh] max-w-[90vw] select-none object-contain",
        data: { lightbox_target: "image" }
      )
    end

    def render_counter
      div(
        aria_live: "polite",
        class: "absolute top-5 left-1/2 -translate-x-1/2 " \
               "rounded-full bg-white/10 px-3 py-1 text-xs " \
               "font-medium text-white",
        data: { lightbox_target: "counter" }
      )
    end

    def render_caption
      div(
        hidden: true,
        class: "absolute bottom-6 left-1/2 max-w-[85vw] " \
               "-translate-x-1/2 rounded-full bg-white/10 px-4 " \
               "py-2 text-center text-sm text-white backdrop-blur-sm",
        data: { lightbox_target: "caption" }
      )
    end
  end
end
