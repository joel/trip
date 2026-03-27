# frozen_string_literal: true

module Components
  class JournalEntryCard < Components::Base
    include Phlex::Rails::Helpers::LinkTo
    include Phlex::Rails::Helpers::DOMID

    def initialize(trip:, journal_entry:)
      @trip = trip
      @entry = journal_entry
    end

    def view_template
      div(id: dom_id(@entry),
          class: "group ha-card overflow-hidden") do
        render_image_area if @entry.images.attached?
        render_content
      end
    end

    private

    def render_image_area
      div(class: "relative aspect-[16/9] overflow-hidden") do
        img(
          src: view_context.url_for(@entry.images.first),
          class: "h-full w-full object-cover transition-transform " \
                 "duration-700 group-hover:scale-105",
          alt: @entry.name
        )
      end
    end

    def render_content
      div(class: "p-6") do
        p(class: "ha-overline") do
          plain @entry.entry_date.to_fs(:long)
        end
        h3(class: "mt-2 font-headline text-xl font-bold " \
                  "tracking-tight") do
          plain @entry.name
        end
        render_location if @entry.location_name.present?
        render_description if @entry.description.present?
        render_meta
        render_footer
      end
    end

    def render_location
      p(class: "mt-1 text-xs " \
               "text-[var(--ha-on-surface-variant)]") do
        plain @entry.location_name
      end
    end

    def render_description
      p(class: "mt-3 text-sm text-[var(--ha-on-surface-variant)] " \
               "line-clamp-2") do
        plain @entry.description
      end
    end

    def render_meta
      count = @entry.comments.size
      return unless count.positive?

      p(class: "mt-2 text-xs text-[var(--ha-on-surface-variant)]") do
        plain "#{count} comment#{"s" if count != 1}"
      end
    end

    def render_footer
      div(class: "mt-4 flex items-center justify-between") do
        link_to(
          view_context.trip_journal_entry_path(@trip, @entry),
          class: "inline-flex items-center gap-1 text-sm " \
                 "font-semibold text-[var(--ha-primary)] " \
                 "transition-all group-hover:gap-2"
        ) do
          plain "Read more \u2192"
        end
        if view_context.allowed_to?(:edit?, @entry)
          link_to(
            "Edit",
            view_context.edit_trip_journal_entry_path(@trip, @entry),
            class: "text-sm font-medium " \
                   "text-[var(--ha-on-surface-variant)] " \
                   "hover:text-[var(--ha-primary)]"
          )
        end
      end
    end
  end
end
