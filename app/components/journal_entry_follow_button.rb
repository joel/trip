# frozen_string_literal: true

module Components
  class JournalEntryFollowButton < Components::Base
    include Phlex::Rails::Helpers::ButtonTo

    def initialize(trip:, journal_entry:, subscribed:)
      @trip = trip
      @journal_entry = journal_entry
      @subscribed = subscribed
    end

    def view_template
      div(id: "journal_entry_#{@journal_entry.id}_mute") do
        if @subscribed
          render_subscribed_button
        else
          render_muted_button
        end
      end
    end

    private

    def render_subscribed_button
      button_to(
        view_context.trip_journal_entry_subscription_path(
          @trip, @journal_entry
        ),
        method: :delete,
        class: "inline-flex h-10 w-10 items-center " \
               "justify-center rounded-full " \
               "bg-[var(--ha-primary-fixed)]/20 " \
               "transition-colors duration-200 " \
               "hover:bg-[var(--ha-primary-fixed)]/40",
        title: "Notifications on \u2014 click to mute",
        aria_label: "Notifications on \u2014 click to mute",
        form: { class: "inline-flex" }
      ) do
        render Components::Icons::Bell.new(
          css: "h-5 w-5 text-[var(--ha-primary)]"
        )
      end
    end

    def render_muted_button
      button_to(
        view_context.trip_journal_entry_subscription_path(
          @trip, @journal_entry
        ),
        method: :post,
        class: "inline-flex h-10 w-10 items-center " \
               "justify-center rounded-full " \
               "transition-colors duration-200 " \
               "hover:bg-[var(--ha-surface-hover)]",
        title: "Notifications off \u2014 click to resume",
        aria_label: "Notifications off \u2014 click to resume",
        form: { class: "inline-flex" }
      ) do
        render Components::Icons::BellOff.new(
          css: "h-5 w-5 text-[var(--ha-on-surface-variant)]"
        )
      end
    end
  end
end
