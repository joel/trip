# frozen_string_literal: true

module Views
  module Rodauth
    class Login < Views::Base
      def view_template
        div(class: "flex min-h-[70vh] items-center justify-center") do
          div(class: "w-full max-w-md space-y-8") do
            render_brand_header
            render Components::RodauthFlash.new
            render_login_panel
          end
        end
      end

      private

      def render_brand_header
        div(class: "text-center") do
          div(class: "mx-auto flex h-16 w-16 items-center " \
                     "justify-center rounded-2xl " \
                     "ha-gradient-aura shadow-lg") do
            span(class: "text-2xl font-bold text-white") { "C" }
          end
          h1(class: "mt-4 font-headline text-3xl font-bold " \
                    "tracking-tighter") do
            plain "Catalyst"
          end
          p(class: "mt-2 text-sm " \
                   "text-[var(--ha-on-surface-variant)]") do
            plain "Your collaborative trip journal"
          end
        end
      end

      def render_login_panel
        div(class: "ha-glass rounded-[2rem] p-8 " \
                   "shadow-[var(--ha-card-shadow)]") do
          h2(class: "font-headline text-xl font-bold") do
            plain "Sign in"
          end
          p(class: "mt-1 text-sm " \
                   "text-[var(--ha-on-surface-variant)]") do
            plain "Enter your email to choose a passkey or " \
                  "request a sign-in link."
          end

          div(class: "mt-6") do
            render Components::RodauthLoginForm.new
          end

          render Components::RodauthLoginFormFooter.new
        end
      end
    end
  end
end
