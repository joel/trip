# frozen_string_literal: true

module Views
  module Trips
    class Show < Views::Base
      include Phlex::Rails::Helpers::LinkTo
      include Phlex::Rails::Helpers::ButtonTo

      def initialize(trip:, journal_entries:)
        @trip = trip
        @journal_entries = journal_entries
      end

      def view_template
        div(class: "space-y-8") do
          render Components::PageHeader.new(
            section: "Trips",
            title: @trip.name,
            subtitle: @trip.description
          ) do
            render_header_actions
          end

          if view_context.notice.present?
            render Components::NoticeBanner.new(
              message: view_context.notice
            )
          end
          if view_context.flash[:alert].present?
            render Components::NoticeBanner.new(
              message: view_context.flash[:alert]
            )
          end

          render_trip_details
          render_state_transitions
          render_journal_entries
        end
      end

      private

      def render_header_actions
        if view_context.allowed_to?(:edit?, @trip)
          link_to("Edit", view_context.edit_trip_path(@trip),
                  class: "ha-button ha-button-secondary")
        end
        link_to(
          "Members",
          view_context.trip_trip_memberships_path(@trip),
          class: "ha-button ha-button-secondary"
        )
        link_to(
          "Checklists",
          view_context.trip_checklists_path(@trip),
          class: "ha-button ha-button-secondary"
        )
        link_to(
          "Exports",
          view_context.trip_exports_path(@trip),
          class: "ha-button ha-button-secondary"
        )
        if view_context.allowed_to?(:destroy?, @trip)
          button_to(
            "Delete", view_context.trip_path(@trip),
            method: :delete,
            class: "ha-button ha-button-danger",
            form: { class: "inline-flex" }
          )
        end
        link_to("Back to trips", view_context.trips_path,
                class: "ha-button ha-button-secondary")
      end

      def render_trip_details
        div(class: "ha-card p-6") do
          div(class: "flex items-center gap-3") do
            render Components::TripStateBadge.new(
              state: @trip.state
            )
            render_date_range
          end
          render_locations
        end
      end

      def render_date_range
        return unless @trip.effective_start_date

        span(class: "text-sm text-[var(--ha-muted)]") do
          plain @trip.effective_start_date.to_fs(:long)
          plain " — #{@trip.effective_end_date.to_fs(:long)}" if @trip.effective_end_date
        end
      end

      def render_locations
        start_loc = @trip.start_location
        end_loc = @trip.end_location
        return unless start_loc || end_loc

        div(class: "mt-3 text-sm text-[var(--ha-muted)]") do
          plain "From: #{start_loc.location_name}" if start_loc
          plain " — To: #{end_loc.location_name}" if end_loc && end_loc.id != start_loc&.id
        end
      end

      def render_state_transitions
        return unless view_context.allowed_to?(:transition?, @trip)

        transitions = Trip::VALID_TRANSITIONS[@trip.state.to_sym]
        return if transitions.blank?

        div(class: "flex flex-wrap gap-2") do
          transitions.each do |target|
            next unless @trip.can_transition_to?(target)

            button_to(
              transition_label(target),
              view_context.transition_trip_path(@trip),
              params: { state: target },
              method: :patch,
              class: "ha-button ha-button-secondary"
            )
          end
        end
      end

      def transition_label(state)
        {
          started: "Start Trip",
          finished: "Finish Trip",
          cancelled: "Cancel Trip",
          archived: "Archive Trip",
          planning: "Reopen Trip"
        }[state] || state.to_s.capitalize
      end

      def render_journal_entries
        div(class: "space-y-4") do
          div(class: "flex items-center justify-between") do
            h2(class: "text-xl font-semibold " \
                      "text-[var(--ha-text)]") do
              plain "Journal Entries"
            end
            if view_context.allowed_to?(
              :create?, @trip.journal_entries.new
            )
              link_to(
                "New entry",
                view_context.new_trip_journal_entry_path(@trip),
                class: "ha-button ha-button-primary"
              )
            end
          end

          if @journal_entries.any?
            div(class: "grid gap-4") do
              @journal_entries.each do |entry|
                render Components::JournalEntryCard.new(
                  trip: @trip, journal_entry: entry
                )
              end
            end
          else
            div(class: "ha-card p-6 text-center") do
              p(class: "text-sm text-[var(--ha-muted)]") do
                plain "No journal entries yet."
              end
            end
          end
        end
      end
    end
  end
end
