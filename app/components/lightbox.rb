# frozen_string_literal: true

module Components
  # Self-contained media group: a flat thumbnail grid whose tiles open
  # a full-screen viewer navigating the whole set (images and videos
  # unified). One instance == one group (used by the trip Gallery).
  # The JournalEntryCard wires the lightbox controller onto its own
  # article instead, but shares LightboxOverlay and the same contract.
  #
  # media: ordered Array of Hashes:
  #   image: { kind: "image", thumb_url:, full_url:, alt:, caption: }
  #   video: { kind: "video", thumb_url: (poster), src: (web rendition),
  #            poster_url:, alt:, caption: }
  class Lightbox < Components::Base
    def initialize(media:, columns: 4)
      @media = media
      @columns = columns
    end

    def view_template
      return if @media.empty?

      div(
        class: "contents",
        data: {
          controller: "lightbox",
          lightbox_urls_value: playable_urls.to_json,
          lightbox_kinds_value: kinds.to_json,
          lightbox_posters_value: posters.to_json,
          lightbox_captions_value:
            @media.map { |m| m[:caption].to_s }.to_json
        }
      ) do
        render_grid
        render Components::LightboxOverlay.new
      end
    end

    private

    def playable_urls
      @media.map { |m| m[:full_url] || m[:src] }
    end

    def kinds
      @media.map { |m| (m[:kind] || "image").to_s }
    end

    def posters
      @media.map { |m| m[:poster_url].to_s }
    end

    def render_grid
      div(class: grid_class) do
        @media.each_with_index { |m, idx| render_tile(m, idx) }
      end
    end

    def render_tile(item, idx)
      button(
        type: "button",
        aria_label: tile_label(item, idx),
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
          src: item[:thumb_url],
          alt: item[:alt].to_s,
          loading: "lazy",
          class: "h-full w-full object-cover transition-transform " \
                 "duration-500 group-hover/photo:scale-110"
        )
        render_play_badge if (item[:kind] || "image").to_s == "video"
      end
    end

    # Centred ▶ badge marking a video tile in the unified grid.
    def render_play_badge
      div(
        class: "absolute inset-0 flex items-center justify-center"
      ) do
        span(
          class: "flex h-12 w-12 items-center justify-center " \
                 "rounded-full bg-black/50 text-white " \
                 "backdrop-blur-sm"
        ) { plain "▶" }
      end
    end

    # Literal class strings only — Tailwind JIT cannot see interpolated
    # class names.
    def grid_class
      cols = { 3 => "lg:grid-cols-3", 4 => "lg:grid-cols-4",
               5 => "lg:grid-cols-5" }.fetch(@columns, "lg:grid-cols-4")
      "grid grid-cols-2 gap-3 sm:grid-cols-3 #{cols}"
    end

    def tile_label(item, idx)
      kind = (item[:kind] || "image").to_s
      base = "View #{kind} #{idx + 1} of #{@media.size}"
      item[:caption].present? ? "#{base} — #{item[:caption]}" : base
    end
  end
end
