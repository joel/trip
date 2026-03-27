# frozen_string_literal: true

module Views
  module Trips
    class Index < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(trips:)
        @trips = trips
      end

      def view_template
        div(class: "space-y-10") do
          render Components::PageHeader.new(
            section: "Trips",
            title: "My Trips",
            subtitle: "Your travel journal collection."
          ) do
            if view_context.allowed_to?(:create?, Trip)
              link_to(
                view_context.new_trip_path,
                class: "ha-button ha-button-primary"
              ) do
                render Components::Icons::Plus.new(css: "h-5 w-5")
                plain "New Trip"
              end
            end
          end

          if view_context.notice.present?
            render Components::NoticeBanner.new(
              message: view_context.notice
            )
          end

          if @trips.any?
            div(id: "trips", class: "grid gap-8 md:grid-cols-2") do
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
        div(class: "ha-card p-12 text-center") do
          h3(class: "font-headline text-xl font-bold") do
            plain "No trips yet"
          end
          p(class: "mt-2 text-sm text-[var(--ha-on-surface-variant)]") do
            plain "Trips will appear here once created."
          end
          if view_context.allowed_to?(:create?, Trip)
            div(class: "mt-6") do
              link_to(
                view_context.new_trip_path,
                class: "ha-button ha-button-primary"
              ) do
                plain "Create your first trip"
              end
            end
          end
        end
      end
    end
  end
end
