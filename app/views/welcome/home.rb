# frozen_string_literal: true

module Views
  module Welcome
    class Home < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def view_template
        if view_context.current_user
          render_logged_in_empty_state
        else
          render_logged_out
        end
      end

      private

      def render_logged_in_empty_state
        div(class: "mx-auto w-full max-w-md space-y-8 text-center") do
          section do
            h1(class: "font-headline text-4xl font-bold tracking-tighter " \
                      "md:text-5xl") do
              plain "Welcome, #{user_first_name}"
            end
            p(class: "mt-4 text-lg text-[var(--ha-on-surface-variant)]") do
              plain "No trips yet! Don't worry, a new one will be added in no time."
            end
          end
          if view_context.allowed_to?(:create?, Trip)
            div do
              link_to(view_context.new_trip_path,
                      class: "ha-button ha-button-primary") do
                render Components::Icons::Plus.new(css: "h-5 w-5")
                plain "New Trip"
              end
            end
          end
        end
      end

      def render_logged_out
        div(class: "mx-auto w-full max-w-md space-y-8") do
          section do
            h1(class: "font-headline text-4xl font-bold tracking-tighter " \
                      "md:text-5xl") do
              plain "Welcome to Catalyst"
            end
            p(class: "mt-2 text-lg text-[var(--ha-on-surface-variant)]") do
              plain "Your collaborative trip journal."
            end
          end
          render_access_card
        end
      end

      def render_access_card
        div(class: "ha-card p-6 ha-rise") do
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

      def user_first_name
        user = view_context.current_user
        return "Explorer" unless user

        name = user.name.presence
        name ? name.split.first : user.email.split("@").first
      end
    end
  end
end
