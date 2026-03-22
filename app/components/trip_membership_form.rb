# frozen_string_literal: true

module Components
  class TripMembershipForm < Components::Base
    include Phlex::Rails::Helpers::FormWith
    include Phlex::Rails::Helpers::Pluralize

    def initialize(trip:, membership:, users:)
      @trip = trip
      @membership = membership
      @users = users
    end

    def view_template
      form_with(
        model: [@trip, @membership],
        url: view_context.trip_trip_memberships_path(@trip),
        class: "space-y-6"
      ) do |form|
        render_errors if @membership.errors.any?

        div do
          form.label :user_id, "User",
                     class: "text-sm font-semibold text-[var(--ha-muted)]"
          form.collection_select(
            :user_id, @users, :id, :email,
            { prompt: "Select a user" },
            { class: "ha-input mt-2" }
          )
        end

        div do
          form.label :role,
                     class: "text-sm font-semibold text-[var(--ha-muted)]"
          form.select(
            :role,
            TripMembership.roles.keys.map { |r| [r.capitalize, r] },
            {},
            { class: "ha-input mt-2" }
          )
        end

        div(class: "flex flex-wrap gap-2") do
          form.submit "Add member",
                      class: "ha-button ha-button-primary"
        end
      end
    end

    private

    def render_errors
      div(
        id: "error_explanation",
        class: "ha-card border border-red-200 bg-red-50/80 " \
               "px-4 py-3 text-sm text-red-700 " \
               "dark:border-red-500/30 dark:bg-red-500/10 " \
               "dark:text-red-200"
      ) do
        h2(class: "font-semibold") do
          plain "#{pluralize(@membership.errors.count, "error")} " \
                "prohibited this membership from being saved:"
        end
        ul(class: "mt-2 list-disc space-y-1 pl-5") do
          @membership.errors.each do |error|
            li { error.full_message }
          end
        end
      end
    end
  end
end
