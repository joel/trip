# frozen_string_literal: true

module Views
  module Exports
    class Show < Views::Base
      include Phlex::Rails::Helpers::LinkTo
      include Phlex::Rails::Helpers::TimeAgoInWords

      def initialize(trip:, export:)
        @trip = trip
        @export = export
      end

      def view_template
        div(class: "space-y-6") do
          render Components::PageHeader.new(
            section: @trip.name,
            title: "#{@export.format.capitalize} Export",
            subtitle: "Requested #{time_ago_in_words(@export.created_at)} ago"
          ) do
            render_header_actions
          end

          render_details
        end
      end

      private

      def render_header_actions
        if @export.completed? && @export.file.attached?
          link_to(
            "Download",
            view_context.download_trip_export_path(
              @trip, @export
            ),
            class: "ha-button ha-button-primary"
          )
        end
        link_to(
          "Back to exports",
          view_context.trip_exports_path(@trip),
          class: "ha-button ha-button-secondary"
        )
      end

      def render_details
        div(class: "ha-card p-6 space-y-4") do
          render_detail_row("Status") do
            render Components::ExportStatusBadge.new(
              status: @export.status
            )
          end
          render_detail_row("Format") do
            plain @export.format.capitalize
          end
          render_detail_row("Requested by") do
            plain @export.user.name || @export.user.email
          end
          if @export.file.attached?
            render_detail_row("File size") do
              plain helpers.number_to_human_size(
                @export.file.byte_size
              )
            end
          end
        end
      end

      def render_detail_row(label, &)
        div(class: "flex items-center justify-between") do
          span(class: "text-sm text-[var(--ha-muted)]") do
            plain label
          end
          span(class: "text-sm font-medium " \
                      "text-[var(--ha-text)]", &)
        end
      end
    end
  end
end
