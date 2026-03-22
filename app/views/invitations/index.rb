# frozen_string_literal: true

module Views
  module Invitations
    class Index < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(invitations:)
        @invitations = invitations
      end

      def view_template
        div(class: "space-y-8") do
          render Components::PageHeader.new(
            section: "Administration",
            title: "Invitations",
            subtitle: "Manage sent invitations."
          ) do
            link_to("New invitation", view_context.new_invitation_path,
                    class: "ha-button ha-button-primary")
          end

          render Components::NoticeBanner.new(message: view_context.notice) if view_context.notice.present?

          if @invitations.any?
            div(id: "invitations", class: "grid gap-4") do
              @invitations.each do |invitation|
                render Components::InvitationCard.new(invitation: invitation)
              end
            end
          else
            div(class: "ha-card p-8 text-center") do
              p(class: "text-sm text-[var(--ha-muted)]") { "No invitations sent yet." }
            end
          end
        end
      end
    end
  end
end
