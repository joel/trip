# frozen_string_literal: true

module Components
  class TripForm < Components::Base
    include Phlex::Rails::Helpers::FormWith
    include Phlex::Rails::Helpers::Pluralize

    def initialize(trip:)
      @trip = trip
    end

    def view_template
      form_with(model: @trip, class: "space-y-6") do |form|
        render_errors if @trip.errors.any?

        div do
          form.label :name,
                     class: "text-sm font-semibold text-[var(--ha-muted)]"
          form.text_field :name, class: "ha-input mt-2"
        end

        div do
          form.label :description,
                     class: "text-sm font-semibold text-[var(--ha-muted)]"
          form.text_area :description, class: "ha-input mt-2", rows: 4
        end

        div(class: "grid gap-4 sm:grid-cols-2") do
          div do
            form.label :start_date,
                       class: "text-sm font-semibold text-[var(--ha-muted)]"
            form.date_field :start_date, class: "ha-input mt-2"
          end
          div do
            form.label :end_date,
                       class: "text-sm font-semibold text-[var(--ha-muted)]"
            form.date_field :end_date, class: "ha-input mt-2"
          end
        end

        div(class: "flex flex-wrap gap-2") do
          form.submit class: "ha-button ha-button-primary"
        end
      end
    end

    private

    def render_errors
      div(
        id: "error_explanation",
        class: "ha-card border border-red-200 bg-red-50/80 " \
               "px-4 py-3 text-sm text-red-700 " \
               "dark:border-red-500/30 dark:bg-red-500/10 " \
               "dark:text-red-200"
      ) do
        h2(class: "font-semibold") do
          plain "#{pluralize(@trip.errors.count, "error")} " \
                "prohibited this trip from being saved:"
        end
        ul(class: "mt-2 list-disc space-y-1 pl-5") do
          @trip.errors.each do |error|
            li { error.full_message }
          end
        end
      end
    end
  end
end
