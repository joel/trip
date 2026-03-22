# frozen_string_literal: true

module Views
  module Trips
    class Index < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(trips:)
        @trips = trips
      end

      def view_template
        div(class: "space-y-8") do
          render Components::PageHeader.new(
            section: "Trips",
            title: "My Trips",
            subtitle: "Your travel journal collection."
          ) do
            if view_context.current_user&.role?(:superadmin)
              link_to(
                "New trip", view_context.new_trip_path,
                class: "ha-button ha-button-primary"
              )
            end
          end

          if view_context.notice.present?
            render Components::NoticeBanner.new(
              message: view_context.notice
            )
          end

          if @trips.any?
            div(id: "trips", class: "grid gap-4") do
              @trips.each do |trip|
                render Components::TripCard.new(trip: trip)
              end
            end
          else
            render_empty_state
          end
        end
      end

      private

      def render_empty_state
        div(class: "ha-card p-8 text-center") do
          p(class: "text-lg font-semibold text-[var(--ha-text)]") do
            plain "No trips yet"
          end
          p(class: "mt-2 text-sm text-[var(--ha-muted)]") do
            plain "Trips will appear here once created."
          end
        end
      end
    end
  end
end
