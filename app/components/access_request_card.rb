# frozen_string_literal: true

module Components
  class AccessRequestCard < Components::Base
    include Phlex::Rails::Helpers::ButtonTo
    include Phlex::Rails::Helpers::DOMID
    include Phlex::Rails::Helpers::TimeAgoInWords

    def initialize(access_request:)
      @access_request = access_request
    end

    def view_template
      div(id: dom_id(@access_request), class: "ha-card p-6") do
        div(class: "flex items-start justify-between gap-4") do
          div do
            p(class: "ha-overline") do
              plain "Access Request"
            end
            p(class: "mt-2 text-lg font-semibold text-[var(--ha-text)]") { @access_request.email }
            p(class: "mt-1 text-xs text-[var(--ha-muted)]") do
              plain "Submitted #{time_ago_in_words(@access_request.created_at)} ago"
            end
          end
          render_status_badge
        end
        render_actions if @access_request.pending?
      end
    end

    STATUS_BADGES = {
      "pending" => "bg-amber-100 text-amber-800 dark:bg-amber-500/10 dark:text-amber-300",
      "approved" => "bg-emerald-100 text-emerald-800 dark:bg-emerald-500/10 dark:text-emerald-300",
      "rejected" => "bg-red-100 text-red-800 dark:bg-red-500/10 dark:text-red-300"
    }.freeze

    private

    def render_status_badge
      css = STATUS_BADGES[@access_request.status]

      span(class: "rounded-full px-3 py-1 text-xs font-medium #{css}") do
        plain @access_request.status.capitalize
      end
    end

    def render_actions
      div(class: "ha-card-actions") do
        button_to("Approve", view_context.approve_access_request_path(@access_request),
                  method: :patch, class: "ha-button ha-button-primary")
        button_to("Reject", view_context.reject_access_request_path(@access_request),
                  method: :patch, class: "ha-button ha-button-danger")
      end
    end
  end
end
