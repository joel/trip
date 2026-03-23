# frozen_string_literal: true

module Views
  module Rodauth
    class Login < Views::Base
      def view_template
        div(class: "space-y-8") do
          div(class: "ha-card p-8") do
            p(class: "ha-overline") do
              plain "Access"
            end
            h1(class: "mt-2 text-3xl font-semibold tracking-tight sm:text-4xl") do
              plain "Sign in"
            end
            p(class: "mt-3 text-sm text-[var(--ha-muted)]") do
              plain "Enter your email to choose a passkey or request a sign-in link."
            end
          end

          render Components::RodauthFlash.new

          div(class: "ha-card p-6 space-y-6") do
            div do
              p(
                class: "ha-overline"
              ) { plain "Email" }
              h2(class: "mt-2 text-lg font-semibold") { plain "Continue with email" }
              p(class: "mt-2 text-sm text-[var(--ha-muted)]") do
                plain "We use your email to find available sign-in methods."
              end
            end

            render Components::RodauthLoginForm.new

            render Components::RodauthLoginFormFooter.new
          end
        end
      end
    end
  end
end
