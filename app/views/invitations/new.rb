# frozen_string_literal: true

module Views
  module Invitations
    class New < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(invitation:)
        @invitation = invitation
      end

      def view_template
        div(class: "space-y-6") do
          render Components::PageHeader.new(
            section: "Invitations",
            title: "Send Invitation",
            subtitle: "Invite someone to create an account."
          )

          div(class: "ha-card p-6") do
            render Components::InvitationForm.new(invitation: @invitation)
          end

          div(class: "flex flex-wrap gap-2") do
            link_to("Back to invitations", view_context.invitations_path,
                    class: "ha-button ha-button-secondary")
          end
        end
      end
    end
  end
end
