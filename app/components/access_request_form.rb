# frozen_string_literal: true

module Components
  class AccessRequestForm < Components::Base
    include Phlex::Rails::Helpers::FormWith
    include Phlex::Rails::Helpers::Pluralize

    def initialize(access_request:)
      @access_request = access_request
    end

    def view_template
      form_with(model: @access_request, url: view_context.submit_access_request_path, class: "space-y-6") do |form|
        render_errors if @access_request.errors.any?

        div do
          form.label :email, class: "text-sm font-medium text-[var(--ha-on-surface-variant)]"
          form.email_field :email, class: "ha-input mt-2", autocomplete: "email",
                                   placeholder: "your@email.com"
        end

        div(class: "flex flex-wrap gap-2") do
          form.submit "Request Access", class: "ha-button ha-button-primary"
        end
      end
    end

    private

    def render_errors
      div(
        class: "rounded-2xl bg-[var(--ha-error-container)] px-5 py-4 text-sm text-[var(--ha-error)]"
      ) do
        h2(class: "font-semibold") do
          plain "#{pluralize(@access_request.errors.count, "error")} prohibited this request:"
        end
        ul(class: "mt-2 list-disc space-y-1 pl-5") do
          @access_request.errors.each do |error|
            li { error.full_message }
          end
        end
      end
    end
  end
end
