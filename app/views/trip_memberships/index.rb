# frozen_string_literal: true

module Views
  module TripMemberships
    class Index < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(trip:, memberships:)
        @trip = trip
        @memberships = memberships
      end

      def view_template
        div(class: "space-y-8") do
          render Components::PageHeader.new(
            section: @trip.name,
            title: "Trip Members",
            subtitle: "Manage who can contribute to this trip."
          ) do
            if view_context.allowed_to?(
              :create?, @trip.trip_memberships.new
            )
              link_to(
                "Add member",
                view_context.new_trip_trip_membership_path(@trip),
                class: "ha-button ha-button-primary"
              )
            end
          end

          if view_context.notice.present?
            render Components::NoticeBanner.new(
              message: view_context.notice
            )
          end

          if @memberships.any?
            div(class: "grid gap-4") do
              @memberships.each do |membership|
                render Components::TripMembershipCard.new(
                  trip: @trip, membership: membership
                )
              end
            end
          else
            div(class: "ha-card p-6 text-center") do
              p(class: "text-sm text-[var(--ha-muted)]") do
                plain "No members yet."
              end
            end
          end

          div(class: "flex flex-wrap gap-2") do
            link_to(
              "Back to trip", view_context.trip_path(@trip),
              class: "ha-button ha-button-secondary"
            )
          end
        end
      end
    end
  end
end
