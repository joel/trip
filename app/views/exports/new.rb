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
        div(class: "space-y-6") do
          render Components::PageHeader.new(
            section: @trip.name,
            title: "New Export",
            subtitle: "Choose the format for your trip export."
          )

          div(class: "ha-card p-6") do
            render_form
          end

          div(class: "flex flex-wrap gap-2") do
            link_to(
              "Back to exports",
              view_context.trip_exports_path(@trip),
              class: "ha-button ha-button-secondary"
            )
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
                                 "YAML frontmatter and images.")
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

      def render_format_option(form, value, label_text, description)
        label(
          class: "flex cursor-pointer items-start gap-3 " \
                 "rounded-xl border border-[var(--ha-border)] " \
                 "p-4 transition hover:bg-[var(--ha-bg-muted)]"
        ) do
          form.radio_button :format, value,
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
