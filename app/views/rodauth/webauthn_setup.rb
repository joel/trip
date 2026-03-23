# frozen_string_literal: true

module Views
  module Rodauth
    class WebauthnSetup < Views::Base
      include Phlex::Rails::Helpers::FormWith
      include Phlex::Rails::Helpers::JavaScriptIncludeTag

      def view_template
        cred = view_context.rodauth.new_webauthn_credential

        div(class: "space-y-8") do
          div(class: "ha-card p-8") do
            p(class: "ha-overline") do
              plain "Security"
            end
            h1(class: "mt-2 text-3xl font-semibold tracking-tight sm:text-4xl") do
              plain "Add a passkey"
            end
            p(class: "mt-3 text-sm text-[var(--ha-muted)]") do
              plain "Register this device to sign in quickly and securely."
            end
          end

          render Components::RodauthFlash.new

          div(class: "ha-card p-6 space-y-6") do
            form_with(
              url: view_context.rodauth.webauthn_setup_path,
              method: :post,
              id: "webauthn-setup-form",
              data: { credential_options: cred.as_json.to_json, turbo: false },
              class: "space-y-6"
            ) do |form|
              raw safe(view_context.rodauth.webauthn_setup_additional_form_tags.to_s)

              form.hidden_field(
                view_context.rodauth.webauthn_setup_challenge_param,
                value: cred.challenge
              )
              form.hidden_field(
                view_context.rodauth.webauthn_setup_challenge_hmac_param,
                value: view_context.rodauth.compute_hmac(cred.challenge)
              )
              form.text_field(
                view_context.rodauth.webauthn_setup_param,
                value: "",
                id: "webauthn-setup",
                class: "hidden",
                aria: { hidden: "true" }
              )

              div(id: "webauthn-setup-button") do
                form.submit(
                  view_context.rodauth.webauthn_setup_button,
                  class: "ha-button ha-button-primary w-full"
                )
              end
            end
          end
        end

        javascript_include_tag(
          view_context.rodauth.webauthn_setup_js_path,
          extname: false
        )
      end
    end
  end
end
