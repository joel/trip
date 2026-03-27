# frozen_string_literal: true

module Components
  class MobileTopBar < Components::Base
    include Phlex::Rails::Helpers::LinkTo

    def view_template
      header(
        class: "fixed top-0 z-40 w-full md:hidden " \
               "ha-glass h-16",
        aria_label: "Mobile header"
      ) do
        div(class: "flex h-full items-center justify-between px-4") do
          render_title
          render_avatar
        end
      end
    end

    private

    def render_title
      link_to(
        view_context.root_path,
        class: "font-headline text-lg font-semibold tracking-tight " \
               "text-[var(--ha-text)]"
      ) { "Catalyst" }
    end

    def render_avatar
      if view_context.rodauth.logged_in? && (user = view_context.current_user)
        link_to(
          view_context.account_path,
          class: "flex h-9 w-9 items-center justify-center rounded-full " \
                 "bg-[var(--ha-primary-container)]/20 " \
                 "text-xs font-semibold text-[var(--ha-primary)]"
        ) do
          plain initials_for(user)
        end
      else
        link_to(
          view_context.rodauth.login_path,
          class: "text-sm font-medium text-[var(--ha-primary)]"
        ) { "Sign in" }
      end
    end

    def initials_for(user)
      name = user.name.presence
      if name
        name.split.pluck(0).first(2).join.upcase
      else
        (user.email&.first || "U").upcase
      end
    end
  end
end
