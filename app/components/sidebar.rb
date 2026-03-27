# frozen_string_literal: true

module Components
  class Sidebar < Components::Base
    include Phlex::Rails::Helpers::LinkTo
    include Phlex::Rails::Helpers::ButtonTo

    NAV_BASE = Components::NavItem::NAV_BASE

    def view_template
      nav(
        class: "ha-nav hidden md:flex h-screen flex-shrink-0 flex-col overflow-hidden " \
               "rounded-r-[2rem] " \
               "bg-[linear-gradient(180deg,var(--ha-panel),var(--ha-panel-strong))] " \
               "text-[var(--ha-panel-text)] " \
               "shadow-[0_20px_40px_-12px_rgba(11,18,32,0.5)]",
        aria_label: "Main navigation"
      ) do
        render_user_profile
        render_main_nav
        render_bottom_nav
      end
    end

    private

    def render_user_profile
      div(class: "px-4 pb-3 pt-5") do
        if logged_in?
          div(class: "flex items-center gap-3") do
            render_avatar
            div do
              p(class: "text-sm font-semibold text-white truncate") do
                plain user_display_name
              end
              p(class: "text-xs text-[var(--ha-panel-muted)] truncate") do
                plain user_role_label
              end
            end
          end
        else
          div(class: "flex items-center gap-3") do
            div(class: "flex h-10 w-10 items-center justify-center " \
                       "rounded-2xl bg-white/10 text-lg font-semibold text-white") { "C" }
            span(class: "text-base font-semibold tracking-tight " \
                        "text-[var(--ha-panel-text)]") { "Catalyst" }
          end
        end
      end
    end

    def render_avatar
      div(class: "flex h-10 w-10 items-center justify-center " \
                 "rounded-2xl bg-[var(--ha-primary-container)]/20 " \
                 "text-sm font-semibold text-[var(--ha-primary-container)]") do
        plain user_initials
      end
    end

    def render_main_nav
      div(class: "flex-1 px-3 pt-4") do
        nav_section_label("Main")
        div(class: "space-y-1") do
          render Components::NavItem.new(
            path: view_context.root_path,
            label: "Overview",
            icon: Components::Icons::Home.new,
            active: view_context.current_page?(view_context.root_path),
            delay: "40ms"
          )
          if logged_in?
            render Components::NavItem.new(
              path: view_context.trips_path,
              label: "Trips",
              icon: Components::Icons::Map.new,
              active: trip_controllers?,
              delay: "80ms"
            )
          end
          if view_context.allowed_to?(:index?, User)
            render Components::NavItem.new(
              path: view_context.users_path,
              label: "Users",
              icon: Components::Icons::Users.new,
              active: view_context.controller_name == "users",
              delay: "120ms"
            )
          end
          if view_context.allowed_to?(:index?, AccessRequest)
            render Components::NavItem.new(
              path: view_context.access_requests_path,
              label: "Requests",
              icon: Components::Icons::Plus.new,
              active: view_context.controller_name == "access_requests",
              delay: "160ms"
            )
            render Components::NavItem.new(
              path: view_context.invitations_path,
              label: "Invitations",
              icon: Components::Icons::CreateAccount.new,
              active: view_context.controller_name == "invitations",
              delay: "200ms"
            )
          end
        end
      end
    end

    def render_bottom_nav
      div(class: "mt-auto px-3 pb-4 pt-6") do
        div(class: "pt-4") do
          nav_section_label("Quick Actions")
          div(class: "space-y-1") do
            if view_context.allowed_to?(:new?, User)
              render Components::NavItem.new(
                path: view_context.new_user_path, label: "New user",
                icon: Components::Icons::Plus.new, delay: "200ms"
              )
            end
            render_theme_toggle
            render_account_section
          end
        end
      end
    end

    def nav_section_label(text)
      p(class: "mb-3 px-2 text-[0.65rem] font-semibold uppercase " \
               "tracking-[0.2em] text-[var(--ha-panel-muted)]") { text }
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
          render Components::Icons::Sun.new(
            css: "h-4 w-4", data: { theme_target: "iconLight" }
          )
          render Components::Icons::Moon.new(
            css: "h-4 w-4 hidden", data: { theme_target: "iconDark" }
          )
        end
        span(class: "ha-nav-label", data: { theme_target: "label" }) do
          plain "Dark mode"
        end
      end
    end

    def render_account_section
      div(class: "mt-4 pt-4") do
        nav_section_label("Account")
        div(class: "space-y-1") do
          if logged_in?
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

    def logged_in? = view_context.rodauth.logged_in?

    def current_user
      @current_user ||= view_context.current_user if logged_in?
    end

    def user_display_name
      return "User" unless current_user

      current_user.name.presence || current_user.email.split("@").first
    end

    def user_initials
      return "U" unless current_user

      name = current_user.name.presence
      return name.split.pluck(0).first(2).join.upcase if name

      current_user.email.first.upcase
    end

    def user_role_label
      return "Member" unless current_user

      if current_user.role?(:superadmin) then "Super Admin"
      elsif current_user.role?(:admin) then "Admin"
      else "Member"
      end
    end

    def trip_controllers?
      %w[trips journal_entries trip_memberships
         comments reactions checklists
         checklist_sections checklist_items
         exports].include?(view_context.controller_name)
    end
  end
end
