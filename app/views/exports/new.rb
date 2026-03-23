# frozen_string_literal: true

module Views
  module Exports
    class New < Views::Base
      include Phlex::Rails::Helpers::LinkTo
      include Phlex::Rails::Helpers::FormWith
      include Phlex::Rails::Helpers::RadioButton

      def initialize(trip:)
        @trip = trip
      end

      def view_template
        div(class: "space-y-8") do
          render Components::PageHeader.new(
            section: @trip.name,
            title: "New Export",
            subtitle: "Choose the format for your trip export."
          ) do
            link_to(
              "Back to exports",
              view_context.trip_exports_path(@trip),
              class: "ha-button ha-button-secondary"
            )
          end

          div(class: "ha-card ha-fade-in p-6") do
            render_form
          end
        end
      end

      private

      def render_form
        form_with(
          url: view_context.trip_exports_path(@trip),
          scope: :export,
          method: :post, class: "space-y-6"
        ) do |f|
          div(class: "space-y-4") do
            render_format_option(f, "markdown",
                                 "Markdown ZIP",
                                 "Obsidian-compatible ZIP with " \
                                 "YAML frontmatter and images.",
                                 checked: true)
            render_format_option(f, "epub",
                                 "ePub",
                                 "E-book format readable on " \
                                 "most devices.")
          end

          div(class: "pt-4") do
            f.submit "Request Export",
                     class: "ha-button ha-button-primary"
          end
        end
      end

      def render_format_option(form, value, label_text,
                               description, checked: false)
        label(
          class: "flex cursor-pointer items-start gap-3 " \
                 "rounded-xl border border-[var(--ha-border)] " \
                 "p-4 transition-colors " \
                 "hover:bg-[var(--ha-surface-hover)] " \
                 "has-[:checked]:border-[var(--ha-accent)] " \
                 "has-[:checked]:bg-[var(--ha-accent)]/5"
        ) do
          form.radio_button :format, value,
                            checked: checked,
                            class: "mt-1 accent-[var(--ha-accent)]"
          div do
            span(class: "text-sm font-medium " \
                        "text-[var(--ha-text)]") do
              plain label_text
            end
            p(class: "text-xs text-[var(--ha-muted)]") do
              plain description
            end
          end
        end
      end
    end
  end
end
