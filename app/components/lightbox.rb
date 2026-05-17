# frozen_string_literal: true

module Components
  # Self-contained image group: a flat thumbnail grid whose tiles open a
  # full-screen viewer navigating the whole set. One instance == one group
  # (used by the trip Gallery). The JournalEntryCard wires the lightbox
  # controller onto its own article instead, but shares LightboxOverlay and
  # the same data contract.
  #
  # images: ordered Array of Hashes:
  #   { thumb_url:, full_url:, alt:, caption: (optional String) }
  class Lightbox < Components::Base
    def initialize(images:, columns: 4)
      @images = images
      @columns = columns
    end

    def view_template
      return if @images.empty?

      div(
        class: "contents",
        data: {
          controller: "lightbox",
          lightbox_urls_value: @images.pluck(:full_url).to_json,
          lightbox_captions_value:
            @images.map { |i| i[:caption].to_s }.to_json
        }
      ) do
        render_grid
        render Components::LightboxOverlay.new
      end
    end

    private

    def render_grid
      div(class: grid_class) do
        @images.each_with_index do |image, idx|
          render_tile(image, idx)
        end
      end
    end

    def render_tile(image, idx)
      button(
        type: "button",
        aria_label: tile_label(image, idx),
        class: "group/photo relative aspect-square overflow-hidden " \
               "rounded-xl bg-[var(--ha-surface-high)] " \
               "cursor-zoom-in focus:outline-none " \
               "focus-visible:ring-2 focus-visible:ring-[var(--ha-primary)]",
        data: {
          lightbox_target: "trigger",
          lightbox_index_param: idx,
          action: "lightbox#open"
        }
      ) do
        img(
          src: image[:thumb_url],
          alt: image[:alt].to_s,
          loading: "lazy",
          class: "h-full w-full object-cover transition-transform " \
                 "duration-500 group-hover/photo:scale-110"
        )
      end
    end

    # Literal class strings only — Tailwind JIT cannot see interpolated
    # class names.
    def grid_class
      cols = { 3 => "lg:grid-cols-3", 4 => "lg:grid-cols-4",
               5 => "lg:grid-cols-5" }.fetch(@columns, "lg:grid-cols-4")
      "grid grid-cols-2 gap-3 sm:grid-cols-3 #{cols}"
    end

    def tile_label(image, idx)
      base = "View photo #{idx + 1} of #{@images.size}"
      image[:caption].present? ? "#{base} — #{image[:caption]}" : base
    end
  end
end
