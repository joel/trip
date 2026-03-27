# frozen_string_literal: true

module Components
  class MobileBottomNav < Components::Base
    include Phlex::Rails::Helpers::LinkTo

    def view_template
      nav(
        class: "fixed bottom-0 left-0 z-50 w-full md:hidden " \
               "ha-glass rounded-t-[2.5rem] " \
               "shadow-[0_-10px_40px_-15px_rgba(0,0,0,0.1)]",
        aria_label: "Mobile navigation"
      ) do
        div(class: "flex items-center justify-around px-4 py-2") do
          nav_tab(view_context.root_path, "Home",
                  Components::Icons::Home.new, home_active?)
          if logged_in?
            nav_tab(view_context.trips_path, "Trips",
                    Components::Icons::Map.new, trip_active?)
          end
          if logged_in? && view_context.allowed_to?(:index?, User)
            nav_tab(view_context.users_path, "Users",
                    Components::Icons::Users.new, users_active?)
          end
          nav_tab(account_path, "Profile",
                  Components::Icons::Person.new, account_active?)
        end
      end
    end

    private

    def nav_tab(path, label, icon, active)
      active_css = "text-[var(--ha-primary)] scale-110"
      idle_css = "text-[var(--ha-muted)] hover:text-[var(--ha-primary)]"
      link_to(
        path,
        class: "flex flex-col items-center gap-0.5 px-3 py-2 " \
               "transition-all duration-300 " \
               "#{active ? active_css : idle_css}",
        aria: { current: (active ? "page" : nil) }
      ) do
        render icon
        span(class: "text-[10px] font-medium uppercase tracking-widest") do
          plain label
        end
      end
    end

    def logged_in? = view_context.rodauth.logged_in?

    def home_active?
      view_context.current_page?(view_context.root_path)
    end

    def trip_active?
      %w[trips journal_entries trip_memberships
         comments reactions checklists
         checklist_sections checklist_items
         exports].include?(view_context.controller_name)
    end

    def users_active?
      view_context.controller_name == "users"
    end

    def account_active?
      view_context.controller_name == "accounts"
    end

    def account_path
      if logged_in?
        view_context.account_path
      else
        view_context.rodauth.login_path
      end
    end
  end
end
