# frozen_string_literal: true

module Views
  module JournalEntries
    class Show < Views::Base
      include Phlex::Rails::Helpers::LinkTo
      include Phlex::Rails::Helpers::ButtonTo

      def initialize(trip:, journal_entry:)
        @trip = trip
        @entry = journal_entry
      end

      def view_template
        div(class: "space-y-8") do
          render Components::PageHeader.new(
            section: @trip.name,
            title: @entry.name,
            subtitle: @entry.entry_date.to_fs(:long)
          ) do
            render_actions
          end

          if view_context.notice.present?
            render Components::NoticeBanner.new(
              message: view_context.notice
            )
          end

          render_entry_details
          render_body if @entry.body.present?
          render_images if @entry.images.attached?
        end
      end

      private

      def render_actions
        link_to(
          "Edit",
          view_context.edit_trip_journal_entry_path(@trip, @entry),
          class: "ha-button ha-button-secondary"
        )
        button_to(
          "Delete",
          view_context.trip_journal_entry_path(@trip, @entry),
          method: :delete,
          class: "ha-button ha-button-danger",
          form: { class: "inline-flex" }
        )
        link_to(
          "Back to trip", view_context.trip_path(@trip),
          class: "ha-button ha-button-secondary"
        )
      end

      def render_entry_details
        div(class: "ha-card p-6") do
          if @entry.location_name.present?
            p(class: "text-sm text-[var(--ha-muted)]") do
              plain @entry.location_name
            end
          end
          if @entry.description.present?
            p(class: "mt-3 text-[var(--ha-text)]") do
              plain @entry.description
            end
          end
        end
      end

      def render_body
        div(class: "ha-card p-6 prose dark:prose-invert " \
                   "max-w-none") do
          unsafe_raw @entry.body.to_s
        end
      end

      def render_images
        div(class: "grid grid-cols-2 gap-4 sm:grid-cols-3") do
          @entry.images.each do |image|
            img(
              src: view_context.url_for(image),
              class: "rounded-xl object-cover",
              alt: @entry.name
            )
          end
        end
      end
    end
  end
end
