# frozen_string_literal: true

module Views
  module Rodauth
    class MultiPhaseLogin < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def view_template
        login_value = view_context.params[view_context.rodauth.login_param]

        div(class: "space-y-8") do
          div(class: "ha-card p-8") do
            p(class: "text-xs font-semibold uppercase tracking-[0.2em] text-[var(--ha-muted)]") do
              plain "Access"
            end
            h1(class: "mt-2 text-3xl font-semibold tracking-tight sm:text-4xl") do
              plain "Choose a sign-in method"
            end
            p(class: "mt-3 text-sm text-[var(--ha-muted)]") do
              plain "Continue for "
              span(class: "font-semibold text-[var(--ha-text)]") { plain login_value }
              plain "."
            end
          end

          render Components::RodauthFlash.new

          div(class: "grid gap-4 md:grid-cols-2") do
            raw safe(view_context.rodauth.render_multi_phase_login_forms.to_s)
          end

          div(
            class: "ha-card p-6 flex flex-col gap-3 sm:flex-row " \
                   "sm:items-center sm:justify-between"
          ) do
            p(class: "text-sm text-[var(--ha-muted)]") do
              plain "Need to use a different email?"
            end
            link_to(
              "Start over",
              view_context.rodauth.login_path,
              class: "ha-button ha-button-secondary"
            )
          end
        end
      end
    end
  end
end
