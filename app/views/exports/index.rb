# frozen_string_literal: true

module Views
  module Exports
    class Index < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(trip:, exports:)
        @trip = trip
        @exports = exports
      end

      def view_template
        div(class: "space-y-8") do
          render Components::PageHeader.new(
            section: @trip.name,
            title: "Exports",
            subtitle: "Download your trip as Markdown or ePub."
          ) do
            render_header_actions
          end

          if @exports.any?
            div(class: "grid gap-4") do
              @exports.each_with_index do |export, idx|
                render Components::ExportCard.new(
                  trip: @trip, export: export,
                  delay: "#{40 + (idx * 40)}ms"
                )
              end
            end
          else
            div(class: "ha-card p-6 text-center") do
              p(class: "text-sm text-[var(--ha-muted)]") do
                plain "No exports yet."
              end
            end
          end
        end
      end

      private

      def render_header_actions
        if view_context.allowed_to?(:create?, @trip,
                                    with: ExportPolicy)
          link_to(
            "New export",
            view_context.new_trip_export_path(@trip),
            class: "ha-button ha-button-primary"
          )
        end
        link_to(
          "Back to trip",
          view_context.trip_path(@trip),
          class: "ha-button ha-button-secondary"
        )
      end
    end
  end
end
