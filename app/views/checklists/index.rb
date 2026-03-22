# frozen_string_literal: true

module Views
  module Checklists
    class Index < Views::Base
      include Phlex::Rails::Helpers::LinkTo

      def initialize(trip:, checklists:)
        @trip = trip
        @checklists = checklists
      end

      def view_template
        div(class: "space-y-6") do
          render Components::PageHeader.new(
            section: @trip.name,
            title: "Checklists",
            subtitle: "Organize your trip with checklists."
          ) do
            render_actions
          end

          if view_context.notice.present?
            render Components::NoticeBanner.new(
              message: view_context.notice
            )
          end

          render_checklists
        end
      end

      private

      def render_actions
        if view_context.allowed_to?(
          :create?, @trip.checklists.new
        )
          link_to(
            "New checklist",
            view_context.new_trip_checklist_path(@trip),
            class: "ha-button ha-button-primary"
          )
        end
        link_to(
          "Back to trip", view_context.trip_path(@trip),
          class: "ha-button ha-button-secondary"
        )
      end

      def render_checklists
        if @checklists.any?
          div(class: "grid gap-4") do
            @checklists.each do |checklist|
              render Components::ChecklistCard.new(
                trip: @trip, checklist: checklist
              )
            end
          end
        else
          div(class: "ha-card p-6 text-center") do
            p(class: "text-sm text-[var(--ha-muted)]") do
              plain "No checklists yet."
            end
          end
        end
      end
    end
  end
end
