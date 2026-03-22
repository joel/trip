# frozen_string_literal: true

module Views
  module AccessRequests
    class New < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(access_request:)
        @access_request = access_request
      end

      def view_template
        div(class: "space-y-6") do
          render Components::PageHeader.new(
            section: "Access",
            title: "Request Access",
            subtitle: "This is a private application. Submit your email to request an invitation."
          )

          div(class: "ha-card p-6") do
            render Components::AccessRequestForm.new(access_request: @access_request)
          end

          div(class: "flex flex-wrap gap-2") do
            link_to("Back to home", view_context.root_path,
                    class: "ha-button ha-button-secondary")
          end
        end
      end
    end
  end
end
