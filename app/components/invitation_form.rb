# frozen_string_literal: true

module Components
  class InvitationForm < Components::Base
    include Phlex::Rails::Helpers::FormWith
    include Phlex::Rails::Helpers::Pluralize

    def initialize(invitation:)
      @invitation = invitation
    end

    def view_template
      form_with(model: @invitation, class: "space-y-6") do |form|
        render_errors if @invitation.errors.any?

        div do
          form.label :email, class: "text-sm font-medium text-[var(--ha-on-surface-variant)]"
          form.email_field :email, class: "ha-input mt-2", autocomplete: "email",
                                   placeholder: "invitee@email.com"
        end

        div(class: "flex flex-wrap gap-2") do
          form.submit "Send Invitation", class: "ha-button ha-button-primary"
        end
      end
    end

    private

    def render_errors
      div(
        class: "rounded-2xl bg-[var(--ha-error-container)] px-5 py-4 text-sm text-[var(--ha-error)]"
      ) do
        h2(class: "font-semibold") do
          plain "#{pluralize(@invitation.errors.count, "error")} prohibited this invitation:"
        end
        ul(class: "mt-2 list-disc space-y-1 pl-5") do
          @invitation.errors.each do |error|
            li { error.full_message }
          end
        end
      end
    end
  end
end
