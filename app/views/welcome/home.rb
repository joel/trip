# frozen_string_literal: true

module Views
  module Welcome
    class Home < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def view_template
        div(class: "space-y-8") do
          render_hero
          render_cards
        end
      end

      private

      def render_hero
        div(class: "ha-card p-8") do
          div(class: "flex flex-col gap-6 md:flex-row md:items-center md:justify-between") do
            div do
              p(class: "text-xs font-semibold uppercase tracking-[0.2em] text-[var(--ha-muted)]") do
                plain "Catalyst Hub"
              end
              h1(class: "mt-2 text-4xl font-semibold tracking-tight sm:text-5xl") { "Welcome home" }
              p(class: "mt-3 text-sm text-[var(--ha-muted)]") do
                plain "Keep people aligned with a clean, focused workspace."
              end
            end
            div(class: "flex flex-wrap gap-2") do
              link_to("View users", view_context.users_path, class: "ha-button ha-button-primary") if view_context.allowed_to?(:index?, User)
            end
          end
        end
      end

      def render_cards
        div(class: "grid gap-4 md:grid-cols-2") do
          render_users_card if view_context.allowed_to?(:index?, User)
          render_auth_card
        end
      end

      def render_users_card
        div(class: "ha-card p-6 ha-rise", style: "animation-delay: 160ms;") do
          p(class: "text-xs font-semibold uppercase tracking-[0.2em] text-[var(--ha-muted)]") { "Users" }
          h2(class: "mt-2 text-2xl font-semibold") { "Stay connected" }
          p(class: "mt-3 text-sm text-[var(--ha-muted)]") do
            plain "Manage who owns and contributes to the latest updates."
          end
          div(class: "mt-5 flex flex-wrap gap-2") do
            link_to("New user", view_context.new_user_path, class: "ha-button ha-button-primary")
            link_to("Browse", view_context.users_path, class: "ha-button ha-button-secondary")
          end
        end
      end

      def render_auth_card
        if view_context.rodauth.logged_in?
          render_passkey_card
        else
          render_signin_card
        end
      end

      def render_passkey_card
        div(class: "ha-card p-6 ha-rise", style: "animation-delay: 240ms;") do
          p(class: "text-xs font-semibold uppercase tracking-[0.2em] text-[var(--ha-muted)]") { "Security" }
          h2(class: "mt-2 text-2xl font-semibold") { "Add a passkey" }
          p(class: "mt-3 text-sm text-[var(--ha-muted)]") do
            plain "Register a passkey per device for faster, safer sign-ins."
          end
          div(class: "mt-5 flex flex-wrap gap-2") do
            link_to("Add passkey", view_context.rodauth.webauthn_setup_path,
                    class: "ha-button ha-button-primary")
            if view_context.rodauth.webauthn_setup?
              link_to("Manage passkeys", view_context.rodauth.webauthn_remove_path,
                      class: "ha-button ha-button-secondary")
            end
          end
        end
      end

      def render_signin_card
        div(class: "ha-card p-6 ha-rise", style: "animation-delay: 240ms;") do
          p(class: "text-xs font-semibold uppercase tracking-[0.2em] text-[var(--ha-muted)]") { "Access" }
          h2(class: "mt-2 text-2xl font-semibold") { "Sign in faster" }
          p(class: "mt-3 text-sm text-[var(--ha-muted)]") do
            plain "Use a one-time email link or a passkey to access your workspace."
          end
          div(class: "mt-5 flex flex-wrap gap-2") do
            link_to("Sign in", view_context.rodauth.login_path, class: "ha-button ha-button-primary")
            link_to("Create account", view_context.rodauth.create_account_path,
                    class: "ha-button ha-button-secondary")
          end
        end
      end
    end
  end
end
