# frozen_string_literal: true

module Components
  class JournalEntryCard < Components::Base
    # Lightbox wiring for the journal-entry card: the cover (index 0) and
    # the in-body photo grid share one lightbox controller instance scoped
    # to the article, alongside the existing feed-entry controller. No
    # captions in the entry context — the surrounding writing provides it.
    module ImageLightbox
      private

      def article_data
        data = {
          controller: "feed-entry",
          feed_entry_expanded_value: "false"
        }
        return data unless @entry.images.attached?

        data[:controller] = "feed-entry lightbox"
        data[:lightbox_urls_value] =
          lightbox_images.pluck(:full_url).to_json
        data
      end

      def lightbox_images
        @lightbox_images ||= @entry.images.map do |image|
          { full_url: full_url(image) }
        end
      end

      # LoadError (not a StandardError) covers a missing libvips on the
      # host; fall back to the original so the page never 500s.
      def variant_url(image, limit)
        view_context.url_for(image.variant(resize_to_limit: limit))
      rescue StandardError, LoadError
        view_context.url_for(image)
      end

      def full_url(image)
        view_context.url_for(image)
      end

      # ── Cover image (collapsed) ──

      def render_cover_image
        button(
          type: "button",
          aria_label: "View photos for #{@entry.name}",
          class: "group/img relative block aspect-[16/9] w-full " \
                 "cursor-zoom-in overflow-hidden focus:outline-none " \
                 "focus-visible:ring-2 focus-visible:ring-inset " \
                 "focus-visible:ring-[var(--ha-primary)]",
          data: {
            lightbox_target: "trigger",
            lightbox_index_param: 0,
            action: "lightbox#open"
          }
        ) do
          img(
            src: variant_url(@entry.images.first, [1200, 800]),
            class: "h-full w-full object-cover " \
                   "transition-transform duration-700 " \
                   "group-hover/img:scale-105",
            alt: @entry.name,
            loading: "lazy"
          )
        end
      end

      # ── In-body photo grid ──

      def render_images
        div(class: "grid grid-cols-2 gap-3 mb-6 " \
                   "md:grid-cols-3") do
          @entry.images.each_with_index do |image, idx|
            render_image_tile(image, idx)
          end
        end
      end

      def render_image_tile(image, idx)
        button(
          type: "button",
          aria_label: "View photo #{idx + 1} of " \
                      "#{@entry.images.size} — #{@entry.name}",
          class: "group/photo block aspect-[4/3] " \
                 "cursor-zoom-in overflow-hidden rounded-xl " \
                 "focus:outline-none focus-visible:ring-2 " \
                 "focus-visible:ring-[var(--ha-primary)]",
          data: {
            lightbox_target: "trigger",
            lightbox_index_param: idx,
            action: "lightbox#open"
          }
        ) do
          img(
            src: variant_url(image, [800, 800]),
            class: "h-full w-full object-cover " \
                   "transition-transform duration-500 " \
                   "group-hover/photo:scale-110",
            alt: "#{@entry.name} — photo #{idx + 1}",
            loading: "lazy"
          )
        end
      end
    end
  end
end
