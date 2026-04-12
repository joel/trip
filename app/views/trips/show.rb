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
        div(class: "space-y-10") do
          render_hero_cover
          render_flash_notices
          render_action_bar
          render_trip_info
          render_state_transitions
          render_journal_entries
        end
      end

      private

      def render_hero_cover
        div(class: "relative -mx-6 -mt-8 sm:-mx-10 overflow-hidden " \
                   "rounded-b-[2rem]") do
          div(class: "relative h-72 md:h-96 " \
                     "bg-gradient-to-br from-[var(--ha-primary)] " \
                     "to-[var(--ha-primary-container)]") do
            div(class: "absolute inset-0 " \
                       "bg-gradient-to-t from-black/50 to-transparent")
            render_hero_content
          end
        end
      end

      def render_hero_content
        div(class: "absolute inset-0 z-10 flex flex-col " \
                   "justify-end p-8 md:p-12") do
          render_location_chips
          h1(class: "font-headline text-4xl font-bold " \
                    "tracking-tight text-white md:text-6xl") do
            plain @trip.name
          end
          if @trip.description.present?
            p(class: "mt-3 max-w-lg text-lg text-white/80 " \
                     "leading-relaxed") do
              plain @trip.description
            end
          end
        end
      end

      def render_location_chips
        chips = []
        chips << @trip.start_location&.location_name
        chips << date_range_label
        chips.compact!
        return if chips.empty?

        div(class: "mb-6 flex flex-wrap gap-3") do
          chips.each do |text|
            span(class: "ha-glass rounded-full px-4 py-1.5 " \
                        "text-[11px] font-medium uppercase " \
                        "tracking-widest text-white") do
              plain text
            end
          end
          render Components::TripStateBadge.new(state: @trip.state)
        end
      end

      def render_flash_notices
        if view_context.notice.present?
          render Components::NoticeBanner.new(
            message: view_context.notice
          )
        end
        return if view_context.flash[:alert].blank?

        render Components::NoticeBanner.new(
          message: view_context.flash[:alert]
        )
      end

      def render_action_bar
        div(class: "flex flex-wrap gap-3") do
          if view_context.allowed_to?(:edit?, @trip)
            link_to("Edit", view_context.edit_trip_path(@trip),
                    class: "ha-button ha-button-secondary")
          end
          link_to("Members",
                  view_context.trip_trip_memberships_path(@trip),
                  class: "ha-button ha-button-secondary")
          link_to("Checklists",
                  view_context.trip_checklists_path(@trip),
                  class: "ha-button ha-button-secondary")
          if view_context.allowed_to?(:index?, @trip,
                                      with: ExportPolicy)
            link_to("Exports",
                    view_context.trip_exports_path(@trip),
                    class: "ha-button ha-button-secondary")
          end
          if view_context.allowed_to?(:destroy?, @trip)
            button_to(
              "Delete", view_context.trip_path(@trip),
              method: :delete,
              class: "ha-button ha-button-danger",
              form: {
                class: "inline-flex",
                data: {
                  turbo_confirm: "Delete this trip and " \
                                 "all its entries?"
                }
              }
            )
          end
          link_to("Back to trips", view_context.trips_path,
                  class: "ha-button ha-button-secondary")
        end
      end

      def render_trip_info
        div(class: "ha-card p-6") do
          div(class: "flex flex-wrap items-center gap-3") do
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

        span(class: "font-mono text-sm " \
                    "text-[var(--ha-on-surface-variant)]") do
          plain @trip.effective_start_date.to_fs(:long)
          plain " — #{@trip.effective_end_date.to_fs(:long)}" if @trip.effective_end_date
        end
      end

      def render_locations
        start_loc = @trip.start_location
        end_loc = @trip.end_location
        return unless start_loc || end_loc

        div(class: "mt-3 text-sm " \
                   "text-[var(--ha-on-surface-variant)]") do
          plain "From: #{start_loc.location_name}" if start_loc
          plain " — To: #{end_loc.location_name}" if end_loc && end_loc.id != start_loc&.id
        end
      end

      def render_state_transitions
        return unless view_context.allowed_to?(:transition?, @trip)

        transitions = Trip::VALID_TRANSITIONS[@trip.state.to_sym]
        return if transitions.blank?

        div(class: "flex flex-wrap gap-3") do
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
        { started: "Start Trip", finished: "Finish Trip",
          cancelled: "Cancel Trip", archived: "Archive Trip",
          planning: "Reopen Trip" }[state] || state.to_s.capitalize
      end

      def render_journal_entries
        div(class: "space-y-6") do
          div(class: "flex items-end justify-between") do
            div do
              p(class: "ha-overline") { plain "JOURNAL FEED" }
              h2(class: "font-headline text-2xl font-bold") do
                plain "The story so far"
              end
            end
            if view_context.allowed_to?(
              :create?, @trip.journal_entries.new
            )
              link_to(
                view_context.new_trip_journal_entry_path(@trip),
                class: "ha-button ha-button-primary"
              ) do
                render Components::Icons::Plus.new(css: "h-5 w-5")
                plain "New Entry"
              end
            end
          end

          if @journal_entries.any?
            div(class: "grid gap-6") do
              @journal_entries.each do |entry|
                render Components::JournalEntryCard.new(
                  trip: @trip, journal_entry: entry
                )
              end
            end
          else
            div(class: "ha-card p-12 text-center") do
              div(class: "mx-auto mb-4 text-[var(--ha-on-surface-variant)]") do
                render Components::Icons::Plus.new(
                  css: "mx-auto h-12 w-12"
                )
              end
              p(class: "text-lg font-medium " \
                       "text-[var(--ha-on-surface-variant)]") do
                plain "No entries yet"
              end
              p(class: "mt-2 mx-auto max-w-md text-sm " \
                       "text-[var(--ha-on-surface-variant)]") do
                plain "Capture a moment, a photo, or a thought " \
                      "from the road. Every entry becomes part " \
                      "of the trip's timeline."
              end
              if view_context.allowed_to?(
                :create?, @trip.journal_entries.new
              )
                link_to(
                  view_context.new_trip_journal_entry_path(@trip),
                  class: "mt-6 ha-button ha-button-primary " \
                         "inline-flex items-center gap-2"
                ) do
                  render Components::Icons::Plus.new(
                    css: "h-5 w-5"
                  )
                  plain "Write the first entry"
                end
              end
            end
          end
        end
      end

      def date_range_label
        return unless @trip.effective_start_date

        start_str = @trip.effective_start_date.strftime("%b %d")
        if @trip.effective_end_date
          "#{start_str} — #{@trip.effective_end_date.strftime("%b %d, %Y")}"
        else
          "#{start_str}, #{@trip.effective_start_date.strftime("%Y")}"
        end
      end
    end
  end
end
