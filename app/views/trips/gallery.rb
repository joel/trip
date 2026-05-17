# frozen_string_literal: true

module Views
  module Trips
    # Flat, newest-first grid of every photo across the trip's journal
    # entries. Each thumbnail opens the shared lightbox over the whole
    # set; the fullscreen caption names the owning entry so context
    # survives without sectioning the page.
    class Gallery < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(trip:, journal_entries:)
        @trip = trip
        @journal_entries = journal_entries
      end

      def view_template
        div(class: "space-y-8") do
          render_header
          if gallery_images.any?
            render Components::Lightbox.new(images: gallery_images)
          else
            render_empty_state
          end
        end
      end

      private

      def render_header
        render Components::PageHeader.new(
          section: @trip.name, title: "Gallery"
        ) do
          link_to("Back to trip", view_context.trip_path(@trip),
                  class: "ha-button ha-button-secondary")
        end
      end

      def gallery_images
        @gallery_images ||= @journal_entries.flat_map do |entry|
          caption = "#{entry.name} · " \
                    "#{entry.entry_date.strftime("%-d %b %Y")}"
          entry.images.map do |image|
            {
              thumb_url: variant_url(image, [600, 600]),
              full_url: full_url(image),
              alt: entry.name,
              caption: caption
            }
          end
        end
      end

      def variant_url(image, limit)
        view_context.url_for(image.variant(resize_to_limit: limit))
      rescue StandardError
        view_context.url_for(image)
      end

      def full_url(image)
        view_context.url_for(image)
      end

      def render_empty_state
        div(class: "flex flex-col items-center justify-center " \
                   "py-16 px-8") do
          div(
            class: "w-full max-w-sm flex flex-col items-center " \
                   "space-y-6 py-16 px-8 rounded-2xl " \
                   "bg-[var(--ha-card)]/40 backdrop-blur-md " \
                   "border border-white/20 dark:border-white/10"
          ) do
            render_empty_icon
            h3(class: "font-headline text-lg font-semibold " \
                      "text-[var(--ha-on-surface)]") do
              plain "No photos yet"
            end
            p(class: "text-sm text-[var(--ha-on-surface-variant)] " \
                     "text-center") do
              plain "Add images to your journal entries to see " \
                    "them here."
            end
          end
        end
      end

      def render_empty_icon
        div(class: "relative w-24 h-24 flex items-center " \
                   "justify-center") do
          div(class: "absolute inset-0 " \
                     "bg-[var(--ha-primary-container)]/20 " \
                     "rounded-full blur-xl")
          div(class: "relative w-16 h-16 rounded-full " \
                     "bg-[var(--ha-surface-high)] flex " \
                     "items-center justify-center") do
            render Components::Icons::Map.new(
              css: "h-8 w-8 text-[var(--ha-primary)]/40"
            )
          end
        end
      end
    end
  end
end
