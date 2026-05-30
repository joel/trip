# frozen_string_literal: true

module Views
  module Trips
    class Index < Views::Base
      include Phlex::Rails::Helpers::LinkTo
      include Phlex::Rails::Helpers::ButtonTo

      def initialize(trips:, discarded: false)
        @trips = trips
        @discarded = discarded
      end

      def view_template
        div(class: "space-y-10") do
          render Components::PageHeader.new(
            section: "Trips",
            title: @discarded ? "Recently Deleted" : "My Trips",
            subtitle: @discarded ? "Soft-deleted trips you can restore." : "Your travel journal collection."
          ) do
            header_actions
          end

          if view_context.notice.present?
            render Components::NoticeBanner.new(
              message: view_context.notice
            )
          end

          if @trips.any?
            render_trip_grid
          else
            render_empty_state
          end
        end
      end

      private

      def header_actions
        if @discarded
          link_to(view_context.trips_path, class: "ha-button ha-button-secondary") do
            plain "Back to trips"
          end
        else
          trash_link
          new_trip_button
        end
      end

      def trash_link
        return unless view_context.allowed_to?(:restore?, Trip)

        link_to(
          view_context.trips_path(discarded: 1),
          class: "ha-button ha-button-secondary"
        ) do
          plain "Recently deleted"
        end
      end

      def new_trip_button
        return unless view_context.allowed_to?(:create?, Trip)

        link_to(
          view_context.new_trip_path,
          class: "ha-button ha-button-primary"
        ) do
          render Components::Icons::Plus.new(css: "h-5 w-5")
          plain "New Trip"
        end
      end

      def render_trip_grid
        div(id: "trips", class: "grid gap-8 md:grid-cols-2") do
          @trips.each do |trip|
            if @discarded
              render_discarded_card(trip)
            else
              render Components::TripCard.new(trip: trip)
            end
          end
        end
      end

      def render_discarded_card(trip)
        div(class: "ha-card flex items-center justify-between gap-4 p-6") do
          div do
            h3(class: "font-headline text-lg font-bold") { plain trip.name }
            p(class: "mt-1 text-sm text-[var(--ha-on-surface-variant)]") do
              plain "Deleted #{trip.discarded_at.to_date.to_fs(:long)}"
            end
          end
          if view_context.allowed_to?(:restore?, trip)
            button_to(
              view_context.restore_trip_path(trip),
              method: :patch,
              class: "ha-button ha-button-primary"
            ) { plain "Restore" }
          end
        end
      end

      def render_empty_state
        div(class: "ha-card p-12 text-center") do
          h3(class: "font-headline text-xl font-bold") do
            plain @discarded ? "No deleted trips" : "No trips yet"
          end
          p(class: "mt-2 text-sm text-[var(--ha-on-surface-variant)]") do
            plain(@discarded ? "Deleted trips will appear here." : "Trips will appear here once created.")
          end
          if !@discarded && view_context.allowed_to?(:create?, Trip)
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
