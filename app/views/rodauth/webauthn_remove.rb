# frozen_string_literal: true

module Views
  module Rodauth
    class WebauthnRemove < Views::Base
      include Phlex::Rails::Helpers::FormWith
      include Phlex::Rails::Helpers::ContentTag

      def view_template
        div(class: "space-y-8") do
          div(class: "ha-card p-8") do
            p(class: "text-xs font-semibold uppercase tracking-[0.2em] text-[var(--ha-muted)]") do
              plain "Security"
            end
            h1(class: "mt-2 text-3xl font-semibold tracking-tight sm:text-4xl") do
              plain "Manage passkeys"
            end
            p(class: "mt-3 text-sm text-[var(--ha-muted)]") do
              plain "Remove a passkey that you no longer use."
            end
          end

          render Components::RodauthFlash.new

          div(class: "ha-card p-6 space-y-6") do
            form_with(
              url: view_context.rodauth.webauthn_remove_path,
              method: :post,
              id: "webauthn-remove-form",
              data: { turbo: false },
              class: "space-y-6"
            ) do |form|
              raw safe(view_context.rodauth.webauthn_remove_additional_form_tags)

              div(class: "flex flex-col gap-3") do
                view_context.rodauth.account_webauthn_usage.each do |id, last_use|
                  formatted_use = if last_use.is_a?(Time)
                                    last_use.strftime(view_context.rodauth.strftime_format)
                                  else
                                    last_use
                                  end

                  remove_error = view_context.rodauth.field_error(
                    view_context.rodauth.webauthn_remove_param
                  )
                  aria_attrs = if remove_error
                                 { invalid: true, describedby: "webauthn_remove_error_message" }
                               else
                                 {}
                               end

                  label(
                    for: "webauthn-remove-#{id}",
                    class: "flex items-center gap-3 rounded-xl border " \
                           "border-[var(--ha-border)] bg-[var(--ha-surface-muted)] " \
                           "px-3 py-2 text-sm text-[var(--ha-text)]"
                  ) do
                    form.radio_button(
                      view_context.rodauth.webauthn_remove_param,
                      id,
                      id: "webauthn-remove-#{id}",
                      class: "h-4 w-4",
                      aria: aria_attrs
                    )
                    span { plain "Last used: #{formatted_use}" }
                  end
                end
              end

              remove_error = view_context.rodauth.field_error(
                view_context.rodauth.webauthn_remove_param
              )
              if remove_error
                span(
                  class: "block text-xs text-red-500",
                  id: "webauthn_remove_error_message"
                ) { remove_error }
              end

              form.submit(
                view_context.rodauth.webauthn_remove_button,
                class: "ha-button ha-button-danger w-full"
              )
            end
          end
        end
      end
    end
  end
end
