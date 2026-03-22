# frozen_string_literal: true

module Views
  module TripMemberships
    class New < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(trip:, membership:, users:)
        @trip = trip
        @membership = membership
        @users = users
      end

      def view_template
        div(class: "space-y-6") do
          render Components::PageHeader.new(
            section: @trip.name,
            title: "Add Member",
            subtitle: "Add a user to this trip."
          )

          div(class: "ha-card p-6") do
            render Components::TripMembershipForm.new(
              trip: @trip, membership: @membership,
              users: @users
            )
          end

          div(class: "flex flex-wrap gap-2") do
            link_to(
              "Back to members",
              view_context.trip_trip_memberships_path(@trip),
              class: "ha-button ha-button-secondary"
            )
          end
        end
      end
    end
  end
end
