# frozen_string_literal: true

module Components
  class ExportCard < Components::Base
    include Phlex::Rails::Helpers::LinkTo
    include Phlex::Rails::Helpers::TimeAgoInWords

    def initialize(trip:, export:)
      @trip = trip
      @export = export
    end

    def view_template
      div(class: "ha-card p-4") do
        div(class: "flex items-center justify-between") do
          div(class: "flex items-center gap-3") do
            render_format_icon
            div do
              p(class: "text-sm font-medium " \
                       "text-[var(--ha-text)]") do
                plain "#{@export.format.capitalize} Export"
              end
              p(class: "text-xs text-[var(--ha-muted)]") do
                plain "Requested #{time_ago_in_words(@export.created_at)} ago"
              end
            end
          end
          div(class: "flex items-center gap-3") do
            render Components::ExportStatusBadge.new(
              status: @export.status
            )
            render_actions
          end
        end
      end
    end

    private

    def render_format_icon
      span(
        class: "flex h-10 w-10 items-center justify-center " \
               "rounded-xl bg-[var(--ha-accent)]/10 " \
               "text-[var(--ha-accent)]"
      ) do
        plain @export.markdown? ? "MD" : "EP"
      end
    end

    def render_actions
      if @export.completed? && @export.file.attached?
        link_to(
          "Download",
          view_context.download_trip_export_path(
            @trip, @export
          ),
          class: "ha-button ha-button-primary text-xs"
        )
      end
      link_to(
        "Details",
        view_context.trip_export_path(@trip, @export),
        class: "ha-button ha-button-secondary text-xs"
      )
    end
  end
end
