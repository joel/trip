# frozen_string_literal: true

module Components
  class Sidebar < Components::Base
    include Phlex::Rails::Helpers::LinkTo
    include Phlex::Rails::Helpers::ButtonTo

    NAV_BASE = Components::NavItem::NAV_BASE

    def view_template
      nav(
        class: "ha-nav hidden md:flex h-screen flex-shrink-0 flex-col overflow-hidden " \
               "rounded-r-[2rem] bg-white/80 backdrop-blur-xl " \
               "text-[var(--ha-on-surface)] " \
               "shadow-[0_20px_40px_-12px_rgba(11,18,32,0.5)] " \
               "dark:bg-[var(--ha-surface)]/80 dark:backdrop-blur-[30px]",
        aria_label: "Main navigation"
      ) do
        render_user_profile
        render_main_nav
        render_bottom_nav
      end
    end

    private

    def render_user_profile
      div(class: "px-8 pb-3 pt-8") do
        if logged_in?
          div(class: "flex items-center gap-4") do
            render_avatar
            div do
              p(class: "text-xl font-bold tracking-tighter truncate") do
                plain user_display_name
              end
              p(class: "text-xs text-[var(--ha-on-surface-variant)] truncate") do
                plain user_role_label
              end
            end
          end
        else
          div(class: "flex items-center gap-4") do
            div(class: "flex h-12 w-12 items-center justify-center " \
                       "rounded-2xl ha-gradient-aura " \
                       "text-2xl font-bold tracking-tighter text-white") { "C" }
            span(class: "text-xl font-bold tracking-tighter") { "Catalyst" }
          end
        end
      end
    end

    def render_avatar
      div(class: "flex h-12 w-12 items-center justify-center " \
                 "rounded-2xl ha-gradient-aura " \
                 "text-sm font-bold text-white") do
        plain user_initials
      end
    end

    def render_main_nav
      div(class: "flex-1 px-4 pt-4") do
        div(class: "space-y-2") do
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
            render Components::NotificationBell.new
          end
          if logged_in? && view_context.allowed_to?(:index?, User)
            render Components::NavItem.new(
              path: view_context.users_path,
              label: "Users",
              icon: Components::Icons::Users.new,
              active: view_context.controller_name == "users",
              delay: "120ms"
            )
          end
          if logged_in? && view_context.allowed_to?(:index?, AccessRequest)
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
      div(class: "mt-auto px-4 pb-4 pt-6") do
        div(class: "space-y-2") do
          if logged_in? && view_context.allowed_to?(:new?, User)
            render Components::NavItem.new(
              path: view_context.new_user_path, label: "New user",
              icon: Components::Icons::Plus.new, delay: "200ms"
            )
          end
          render_theme_toggle
          render_account_section
        end
        render_status_footer
      end
    end

    def render_theme_toggle
      button(
        type: "button",
        class: "#{NAV_BASE} ha-rise w-full",
        style: "animation-delay: 240ms;",
        data: { action: "theme#toggle" },
        aria_label: "Toggle dark mode"
      ) do
        render Components::Icons::Sun.new(
          css: "h-4 w-4", data: { theme_target: "iconLight" }
        )
        render Components::Icons::Moon.new(
          css: "h-4 w-4 hidden", data: { theme_target: "iconDark" }
        )
        span(class: "ha-nav-label", data: { theme_target: "label" }) do
          plain "Dark mode"
        end
      end
    end

    def render_account_section
      div(class: "mt-2") do
        div(class: "space-y-2") do
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
      render Components::NavItem.new(**passkey_nav_attrs)
      render_logout_button
    end

    def passkey_nav_attrs
      if view_context.rodauth.webauthn_setup?
        { path: view_context.rodauth.webauthn_remove_path,
          label: "Manage passkeys",
          icon: Components::Icons::KeyRemove.new, delay: "300ms" }
      else
        { path: view_context.rodauth.webauthn_setup_path,
          label: "Add passkey",
          icon: Components::Icons::Key.new, delay: "300ms" }
      end
    end

    def render_logout_button
      button_to(
        view_context.rodauth.logout_path,
        method: :post,
        form: { class: "w-full" },
        class: "#{NAV_BASE} ha-rise w-full text-left",
        style: "animation-delay: 380ms;"
      ) do
        render Components::Icons::SignOut.new
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

    def render_status_footer
      return unless logged_in?

      div(class: "mt-4 pt-4") do
        div(class: "rounded-2xl bg-[var(--ha-surface-low)] p-4") do
          p(class: "text-[10px] font-bold uppercase tracking-widest " \
                   "text-[var(--ha-on-surface-variant)] mb-1") do
            plain "Status"
          end
          p(class: "text-sm font-medium") do
            count = current_user&.trips&.count || 0
            plain "#{count} Trip#{"s" if count != 1}"
          end
        end
      end
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
