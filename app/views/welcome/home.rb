# frozen_string_literal: true

module Views
  module Welcome
    class Home < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def view_template
        if view_context.rodauth.logged_in?
          render_logged_in_dashboard
        else
          render_logged_out
        end
      end

      private

      def render_logged_in_dashboard
        div(class: "space-y-12") do
          render_hero_welcome
          render_quick_actions
          render_active_trip_section
          render_info_cards
        end
      end

      def render_hero_welcome
        section(class: "mb-2") do
          h1(class: "font-headline text-4xl font-bold tracking-tighter " \
                    "md:text-5xl") do
            plain "Welcome, #{user_first_name}"
          end
          p(class: "mt-2 text-lg text-[var(--ha-on-surface-variant)]") do
            plain "Ready for your next adventure?"
          end
        end
      end

      def render_quick_actions
        section(class: "flex flex-wrap gap-3") do
          if view_context.allowed_to?(:create?, Trip)
            link_to(
              view_context.new_trip_path,
              class: "ha-button ha-button-primary"
            ) do
              render Components::Icons::Plus.new(css: "h-5 w-5")
              plain "New Trip"
            end
          end
          if active_trip
            link_to(
              view_context.trip_path(active_trip),
              class: "ha-button ha-button-secondary"
            ) do
              render Components::Icons::Map.new(css: "h-5 w-5")
              plain "Continue Trip"
            end
          end
        end
      end

      def render_active_trip_section
        return unless active_trip

        section do
          div(class: "group relative overflow-hidden rounded-[2rem] " \
                     "bg-[var(--ha-card)] " \
                     "shadow-[var(--ha-card-shadow)] " \
                     "transition-all duration-500 " \
                     "hover:-translate-y-1") do
            render_trip_hero_image
            render_trip_details
          end
        end
      end

      def render_trip_hero_image
        div(class: "relative h-64 overflow-hidden " \
                   "bg-gradient-to-br from-[var(--ha-primary)] " \
                   "to-[var(--ha-primary-container)]") do
          div(class: "absolute top-6 left-6 z-10") do
            render Components::TripStateBadge.new(state: active_trip.state)
          end
        end
      end

      def render_trip_details
        div(class: "p-8") do
          div(class: "mb-6") do
            h3(class: "font-headline text-2xl font-bold") do
              plain active_trip.name
            end
            if active_trip.effective_start_date
              p(class: "mt-1 text-sm text-[var(--ha-on-surface-variant)]") do
                plain active_trip.effective_start_date.strftime("%b %Y")
              end
            end
          end
          render_trip_stats
        end
      end

      def render_trip_stats
        div(class: "grid grid-cols-2 gap-4") do
          stat_card("Entries",
                    active_trip.journal_entries.count,
                    "bg-[var(--ha-primary-container)]/10 " \
                    "text-[var(--ha-primary)]")
          stat_card("Checklists",
                    active_trip.checklists.count,
                    "bg-[var(--ha-secondary-container)]/10 " \
                    "text-[var(--ha-secondary)]")
        end
      end

      def stat_card(label, value, icon_css)
        div(class: "flex items-center gap-4 rounded-2xl " \
                   "bg-[var(--ha-surface-low)] p-4") do
          div(class: "rounded-xl p-2 #{icon_css}") do
            render Components::Icons::Map.new(css: "h-5 w-5")
          end
          div do
            p(class: "text-xl font-bold leading-none") { plain value.to_s }
            p(class: "mt-1 text-[10px] font-bold uppercase " \
                     "tracking-widest text-[var(--ha-on-surface-variant)]") do
              plain label
            end
          end
        end
      end

      def render_info_cards
        div(class: "grid gap-6 md:grid-cols-2") do
          render_users_card if view_context.allowed_to?(:index?, User)
          render_passkey_card
        end
      end

      def render_users_card
        div(class: "ha-card p-6 ha-rise", style: "animation-delay: 160ms;") do
          p(class: "ha-overline") { "Team" }
          h2(class: "mt-2 font-headline text-2xl font-bold") do
            plain "Stay connected"
          end
          p(class: "mt-3 text-sm text-[var(--ha-on-surface-variant)]") do
            plain "Manage who owns and contributes to the latest updates."
          end
          div(class: "mt-6 flex flex-wrap gap-3") do
            link_to("New user", view_context.new_user_path,
                    class: "ha-button ha-button-primary")
            link_to("Browse", view_context.users_path,
                    class: "ha-button ha-button-secondary")
          end
        end
      end

      def render_passkey_card
        div(class: "ha-card p-6 ha-rise", style: "animation-delay: 240ms;") do
          p(class: "ha-overline") { "Security" }
          h2(class: "mt-2 font-headline text-2xl font-bold") do
            plain "Add a passkey"
          end
          p(class: "mt-3 text-sm text-[var(--ha-on-surface-variant)]") do
            plain "Register a passkey per device for faster, safer sign-ins."
          end
          div(class: "mt-6 flex flex-wrap gap-3") do
            link_to("Add passkey",
                    view_context.rodauth.webauthn_setup_path,
                    class: "ha-button ha-button-primary")
            if view_context.rodauth.webauthn_setup?
              link_to("Manage passkeys",
                      view_context.rodauth.webauthn_remove_path,
                      class: "ha-button ha-button-secondary")
            end
          end
        end
      end

      def render_logged_out
        div(class: "space-y-12") do
          section do
            h1(class: "font-headline text-4xl font-bold tracking-tighter " \
                      "md:text-5xl") do
              plain "Welcome to Catalyst"
            end
            p(class: "mt-2 text-lg text-[var(--ha-on-surface-variant)]") do
              plain "Your collaborative trip journal."
            end
          end
          div(class: "mx-auto w-full max-w-md") do
            render_access_card
          end
        end
      end

      def render_access_card
        div(class: "ha-card p-6 ha-rise", style: "animation-delay: 160ms;") do
          p(class: "ha-overline") { "Access" }
          h2(class: "mt-2 font-headline text-2xl font-bold") do
            plain "Request an invitation"
          end
          p(class: "mt-3 text-sm text-[var(--ha-on-surface-variant)]") do
            plain "This is an invite-only app. Request access to get started."
          end
          div(class: "mt-6") do
            link_to("Request Access",
                    view_context.new_access_request_path,
                    class: "ha-button ha-button-primary")
          end
        end
      end

      def active_trip
        return @active_trip if defined?(@active_trip)

        user = view_context.current_user if view_context.respond_to?(:current_user)
        @active_trip = user&.trips&.find_by(state: :started)
      end

      def user_first_name
        user = view_context.current_user
        return "Explorer" unless user

        name = user.name.presence
        name ? name.split.first : user.email.split("@").first
      end
    end
  end
end
