# frozen_string_literal: true

module Views
  module AccessRequests
    class Index < Views::Base
      def initialize(access_requests:)
        @access_requests = access_requests
      end

      def view_template
        div(class: "space-y-8") do
          render Components::PageHeader.new(
            section: "Administration",
            title: "Access Requests",
            subtitle: "Review and manage incoming access requests."
          )

          render Components::NoticeBanner.new(message: view_context.notice) if view_context.notice.present?

          if @access_requests.any?
            div(id: "access_requests", class: "grid gap-4") do
              @access_requests.each do |access_request|
                render Components::AccessRequestCard.new(access_request: access_request)
              end
            end
          else
            div(class: "ha-card p-8 text-center") do
              p(class: "text-sm text-[var(--ha-muted)]") { "No access requests yet." }
            end
          end
        end
      end
    end
  end
end
