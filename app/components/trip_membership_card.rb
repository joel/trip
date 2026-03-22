# frozen_string_literal: true

module Components
  class TripMembershipCard < Components::Base
    include Phlex::Rails::Helpers::ButtonTo
    include Phlex::Rails::Helpers::DOMID

    ROLE_COLORS = {
      "contributor" => "bg-sky-100 text-sky-800 " \
                       "dark:bg-sky-500/10 dark:text-sky-300",
      "viewer" => "bg-zinc-100 text-zinc-800 " \
                  "dark:bg-zinc-500/10 dark:text-zinc-300"
    }.freeze

    def initialize(trip:, membership:)
      @trip = trip
      @membership = membership
    end

    def view_template
      div(id: dom_id(@membership), class: "ha-card p-6") do
        div(class: "flex items-start justify-between gap-4") do
          div do
            p(class: "text-xs font-semibold uppercase " \
                     "tracking-[0.2em] text-[var(--ha-muted)]") do
              plain "Member"
            end
            p(class: "mt-2 text-lg font-semibold " \
                     "text-[var(--ha-text)]") do
              plain @membership.user.name || @membership.user.email
            end
            p(class: "mt-1 text-xs text-[var(--ha-muted)]") do
              plain @membership.user.email
            end
          end
          render_role_badge
        end
        render_actions
      end
    end

    private

    def render_role_badge
      css = ROLE_COLORS[@membership.role]
      span(
        class: "rounded-full px-3 py-1 text-xs font-medium #{css}"
      ) do
        plain @membership.role.capitalize
      end
    end

    def render_actions
      return unless view_context.allowed_to?(:destroy?, @membership)

      div(class: "mt-5 flex flex-wrap gap-2") do
        button_to(
          "Remove",
          view_context.trip_trip_membership_path(@trip, @membership),
          method: :delete,
          class: "ha-button ha-button-danger"
        )
      end
    end
  end
end
