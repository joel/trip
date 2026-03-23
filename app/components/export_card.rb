# frozen_string_literal: true

module Components
  class ExportCard < Components::Base
    include Phlex::Rails::Helpers::LinkTo
    include Phlex::Rails::Helpers::TimeAgoInWords
    include Phlex::Rails::Helpers::DOMID

    def initialize(trip:, export:, delay: "40ms")
      @trip = trip
      @export = export
      @delay = delay
    end

    def view_template
      div(
        id: dom_id(@export),
        class: "ha-card ha-rise p-6",
        style: "animation-delay: #{@delay};"
      ) do
        div(class: "flex items-start justify-between gap-4") do
          div(class: "flex items-center gap-3") do
            render_format_icon
            div do
              p(class: "ha-overline") { "Export" }
              p(class: "mt-1 text-base font-semibold " \
                       "text-[var(--ha-text)]") do
                plain "#{@export.format.capitalize} Export"
              end
              p(class: "mt-1 text-xs text-[var(--ha-muted)]") do
                plain "Requested #{time_ago_in_words(@export.created_at)} ago"
                plain " by #{@export.user.name || @export.user.email}" if view_context.current_user&.role?(:superadmin)
              end
            end
          end
          render Components::ExportStatusBadge.new(
            status: @export.status
          )
        end
        render_actions
      end
    end

    private

    def render_format_icon
      span(
        class: "flex h-10 w-10 items-center justify-center " \
               "rounded-2xl bg-[var(--ha-accent)]/10 " \
               "font-mono text-xs font-semibold tracking-wider " \
               "text-[var(--ha-accent)]"
      ) do
        plain @export.markdown? ? "MD" : "EP"
      end
    end

    def render_actions
      div(class: "ha-card-actions") do
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
          "Details",
          view_context.trip_export_path(@trip, @export),
          class: "ha-button ha-button-secondary"
        )
      end
    end
  end
end
