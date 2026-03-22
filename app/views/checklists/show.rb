# frozen_string_literal: true

module Views
  module Checklists
    class Show < Views::Base
      include Phlex::Rails::Helpers::LinkTo
      include Phlex::Rails::Helpers::ButtonTo
      include Phlex::Rails::Helpers::FormWith

      def initialize(trip:, checklist:)
        @trip = trip
        @checklist = checklist
      end

      def view_template
        div(class: "space-y-6") do
          render Components::PageHeader.new(
            section: @trip.name,
            title: @checklist.name
          ) do
            render_header_actions
          end

          if view_context.notice.present?
            render Components::NoticeBanner.new(
              message: view_context.notice
            )
          end

          render_sections
          render_add_section if can_modify?
        end
      end

      private

      def render_header_actions
        if view_context.allowed_to?(:edit?, @checklist)
          link_to(
            "Edit",
            view_context.edit_trip_checklist_path(
              @trip, @checklist
            ),
            class: "ha-button ha-button-secondary"
          )
        end
        if view_context.allowed_to?(:destroy?, @checklist)
          button_to(
            "Delete",
            view_context.trip_checklist_path(
              @trip, @checklist
            ),
            method: :delete,
            class: "ha-button ha-button-danger",
            form: { class: "inline-flex" }
          )
        end
        link_to(
          "Back to checklists",
          view_context.trip_checklists_path(@trip),
          class: "ha-button ha-button-secondary"
        )
      end

      def render_sections
        sections = @checklist.checklist_sections
                             .includes(:checklist_items)
        if sections.any?
          sections.each { |section| render_section(section) }
        else
          div(class: "ha-card p-6 text-center") do
            p(class: "text-sm text-[var(--ha-muted)]") do
              plain "No sections yet. Add a section to start."
            end
          end
        end
      end

      def render_section(section)
        div(class: "ha-card p-6 space-y-3") do
          div(class: "flex items-center justify-between") do
            h3(class: "text-base font-semibold " \
                      "text-[var(--ha-text)]") do
              plain section.name
            end
            render_delete_section(section) if can_modify?
          end

          section.checklist_items.each do |item|
            render Components::ChecklistItemRow.new(
              trip: @trip, checklist: @checklist, item: item
            )
          end

          render_add_item(section) if can_modify?
        end
      end

      def render_delete_section(section)
        button_to(
          "Remove section",
          view_context.trip_checklist_checklist_section_path(
            @trip, @checklist, section
          ),
          method: :delete,
          class: "text-xs text-red-500 hover:text-red-700",
          form: { class: "inline-flex" }
        )
      end

      def render_add_item(section)
        form_with(
          url: view_context.trip_checklist_checklist_items_path(
            @trip, @checklist
          ),
          class: "flex gap-2 mt-2"
        ) do |form|
          form.hidden_field(
            :checklist_section_id,
            name: "checklist_item[checklist_section_id]",
            value: section.id
          )
          form.text_field(
            :content,
            name: "checklist_item[content]",
            placeholder: "Add item...",
            class: "ha-input flex-1 text-sm"
          )
          form.submit "Add",
                      class: "ha-button ha-button-primary text-sm"
        end
      end

      def render_add_section
        div(class: "ha-card p-4") do
          form_with(
            url: view_context
                 .trip_checklist_checklist_sections_path(
                   @trip, @checklist
                 ),
            class: "flex gap-2"
          ) do |form|
            form.text_field(
              :name,
              name: "checklist_section[name]",
              placeholder: "New section name...",
              class: "ha-input flex-1 text-sm"
            )
            form.submit "Add section",
                        class: "ha-button ha-button-secondary " \
                               "text-sm"
          end
        end
      end

      def can_modify?
        view_context.allowed_to?(:edit?, @checklist)
      end
    end
  end
end
