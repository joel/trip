# frozen_string_literal: true

module Components
  class Sidebar < Components::Base
    include Phlex::Rails::Helpers::LinkTo
    include Phlex::Rails::Helpers::ButtonTo

    NAV_BASE = Components::NavItem::NAV_BASE

    def view_template
      details(
        class: "ha-nav flex h-screen flex-shrink-0 flex-col overflow-hidden " \
               "bg-[linear-gradient(180deg,var(--ha-panel),var(--ha-panel-strong))] " \
               "text-[var(--ha-panel-text)] shadow-[18px_0_45px_-30px_rgba(15,23,42,0.7)]",
        open: true
      ) do
        render_summary
        div(class: "ha-nav-body flex h-full flex-1 flex-col") do
          render_main_nav
          render_bottom_nav
        end
      end
    end

    private

    def render_summary
      summary(class: "flex cursor-pointer items-center justify-between gap-3 px-4 pb-3 pt-4",
              aria_label: "Toggle menu") do
        div(class: "ha-nav-brand flex items-center gap-3") do
          div(class: "flex h-10 w-10 items-center justify-center rounded-2xl bg-white/10 " \
                     "text-lg font-semibold text-white") { "S" }
          span(class: "ha-nav-label text-base font-semibold tracking-tight " \
                      "text-[var(--ha-panel-text)]") { "Catalyst" }
        end
        span(class: "ha-nav-toggle flex h-9 w-9 items-center justify-center rounded-xl " \
                    "bg-white/10 text-white/70") do
          render Components::Icons::ChevronLeft.new
        end
      end
    end

    def render_main_nav
      div(class: "px-3") do
        div(class: "ha-nav-label mb-3 px-2 text-[0.65rem] font-semibold uppercase " \
                   "tracking-[0.2em] text-[var(--ha-panel-muted)]") { "Main" }
        nav(class: "space-y-1") do
          render Components::NavItem.new(
            path: view_context.root_path,
            label: "Overview",
            icon: Components::Icons::Home.new,
            active: view_context.current_page?(view_context.root_path),
            delay: "40ms"
          )
          if view_context.allowed_to?(:index?, User)
            render Components::NavItem.new(
              path: view_context.users_path,
              label: "Users",
              icon: Components::Icons::Users.new,
              active: view_context.controller_name == "users",
              delay: "120ms"
            )
          end
        end
      end
    end

    def render_bottom_nav
      div(class: "mt-auto px-3 pb-4 pt-6") do
        div(class: "border-t border-white/10 pt-4") do
          render_quick_actions_label
          div(class: "space-y-1") do
            render_new_user_link
            render_theme_toggle
            render_account_section
          end
        end
      end
    end

    def render_quick_actions_label
      div(class: "ha-nav-label mb-3 px-2 text-[0.65rem] font-semibold uppercase " \
                 "tracking-[0.2em] text-[var(--ha-panel-muted)]") { "Quick Actions" }
    end

    def render_new_user_link
      return unless view_context.allowed_to?(:new?, User)

      render Components::NavItem.new(
        path: view_context.new_user_path,
        label: "New user",
        icon: Components::Icons::Plus.new,
        delay: "200ms"
      )
    end

    def render_theme_toggle
      button(
        type: "button",
        class: "ha-nav-item ha-rise flex w-full items-center gap-3 rounded-2xl px-3 py-2.5 " \
               "text-sm font-medium text-[var(--ha-panel-muted)] transition hover:bg-white/10 " \
               "hover:text-[var(--ha-panel-text)]",
        style: "animation-delay: 240ms;",
        data: { action: "theme#toggle" },
        aria_label: "Toggle dark mode"
      ) do
        span(class: "flex h-8 w-8 items-center justify-center rounded-xl bg-white/10") do
          render Components::Icons::Sun.new(css: "h-4 w-4", data: { theme_target: "iconLight" })
          render Components::Icons::Moon.new(css: "h-4 w-4 hidden", data: { theme_target: "iconDark" })
        end
        span(class: "ha-nav-label", data: { theme_target: "label" }) { "Dark mode" }
      end
    end

    def render_account_section
      div(class: "mt-4 border-t border-white/10 pt-4") do
        div(class: "ha-nav-label mb-3 px-2 text-[0.65rem] font-semibold uppercase " \
                   "tracking-[0.2em] text-[var(--ha-panel-muted)]") { "Account" }
        div(class: "space-y-1") do
          if view_context.rodauth.logged_in?
            render_logged_in_links
          else
            render_logged_out_links
          end
        end
      end
    end

    def render_logged_in_links
      render Components::NavItem.new(
        path: view_context.account_path,
        label: "My account",
        icon: Components::Icons::Person.new,
        delay: "260ms"
      )
      render Components::NavItem.new(
        path: view_context.rodauth.webauthn_setup_path,
        label: "Add passkey",
        icon: Components::Icons::Key.new,
        delay: "300ms"
      )
      if view_context.rodauth.webauthn_setup?
        render Components::NavItem.new(
          path: view_context.rodauth.webauthn_remove_path,
          label: "Manage passkeys",
          icon: Components::Icons::KeyRemove.new,
          delay: "340ms"
        )
      end
      render_logout_button
    end

    def render_logout_button
      button_to(
        view_context.rodauth.logout_path,
        method: :post,
        form: { class: "w-full" },
        class: "#{NAV_BASE} ha-rise w-full text-left",
        style: "animation-delay: 380ms;"
      ) do
        span(class: "flex h-8 w-8 items-center justify-center rounded-xl bg-white/10") do
          render Components::Icons::SignOut.new
        end
        span(class: "ha-nav-label") { "Sign out" }
      end
    end

    def render_logged_out_links
      render Components::NavItem.new(
        path: view_context.rodauth.login_path,
        label: "Sign in",
        icon: Components::Icons::SignIn.new,
        delay: "300ms"
      )
      render Components::NavItem.new(
        path: view_context.rodauth.create_account_path,
        label: "Create account",
        icon: Components::Icons::CreateAccount.new,
        delay: "340ms"
      )
    end
  end
end
