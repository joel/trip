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
                     class: "text-sm font-medium text-[var(--ha-on-surface-variant)]"
          form.collection_select(
            :user_id, @users, :id, :email,
            { prompt: "Select a user" },
            { class: "ha-input mt-2" }
          )
        end

        div do
          form.label :role,
                     class: "text-sm font-medium text-[var(--ha-on-surface-variant)]"
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
        class: "rounded-2xl bg-[var(--ha-error-container)] " \
               "px-5 py-4 text-sm text-[var(--ha-error)]"
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
