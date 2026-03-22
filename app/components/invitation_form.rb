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
          form.label :email, class: "text-sm font-semibold text-[var(--ha-muted)]"
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
        class: "ha-card border border-red-200 bg-red-50/80 px-4 py-3 text-sm text-red-700 " \
               "dark:border-red-500/30 dark:bg-red-500/10 dark:text-red-200"
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
