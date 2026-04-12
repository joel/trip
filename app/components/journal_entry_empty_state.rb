# frozen_string_literal: true

module Components
  class JournalEntryEmptyState < Components::Base
    include Phlex::Rails::Helpers::LinkTo

    def initialize(trip:)
      @trip = trip
    end

    def view_template
      div(class: "ha-card p-12 text-center ha-rise") do
        render_icon
        render_heading
        render_description
        render_cta if can_create?
      end
    end

    private

    def render_icon
      div(class: "mx-auto mb-6") do
        span(
          class: "inline-flex h-16 w-16 items-center " \
                 "justify-center rounded-full " \
                 "bg-[var(--ha-surface-muted)]"
        ) do
          render Components::Icons::Plus.new(
            css: "h-8 w-8 " \
                 "text-[var(--ha-on-surface-variant)]"
          )
        end
      end
    end

    def render_heading
      p(class: "font-headline text-lg font-medium") do
        plain "No entries yet"
      end
    end

    def render_description
      p(class: "mt-2 mx-auto max-w-md text-sm " \
               "text-[var(--ha-on-surface-variant)]") do
        plain "Capture a moment, a photo, or a thought " \
              "from the road. Every entry becomes part " \
              "of the trip\u2019s timeline."
      end
    end

    def render_cta
      div(class: "mt-6") do
        link_to(
          view_context.new_trip_journal_entry_path(@trip),
          class: "ha-button ha-button-primary " \
                 "inline-flex items-center gap-2"
        ) do
          render Components::Icons::Plus.new(
            css: "h-5 w-5"
          )
          plain "Write the first entry"
        end
      end
    end

    def can_create?
      view_context.allowed_to?(
        :create?, @trip.journal_entries.new
      )
    end
  end
end
