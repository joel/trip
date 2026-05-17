# frozen_string_literal: true

module Components
  class JournalEntryForm < Components::Base
    include Phlex::Rails::Helpers::FormWith
    include Phlex::Rails::Helpers::Pluralize
    include Phlex::Rails::Helpers::RichTextArea

    def initialize(trip:, journal_entry:)
      @trip = trip
      @entry = journal_entry
    end

    def view_template
      form_with(
        model: [@trip, @entry], class: "space-y-6"
      ) do |form|
        render_errors if @entry.errors.any?

        div do
          form.label :name,
                     class: "text-sm font-medium text-[var(--ha-on-surface-variant)]"
          form.text_field :name, class: "ha-input mt-2"
        end

        div do
          form.label :entry_date,
                     class: "text-sm font-medium text-[var(--ha-on-surface-variant)]"
          form.date_field :entry_date, class: "ha-input mt-2"
        end

        div do
          form.label :description,
                     class: "text-sm font-medium text-[var(--ha-on-surface-variant)]"
          form.text_area :description, class: "ha-input mt-2", rows: 3
        end

        div do
          form.label :location_name, "Location",
                     class: "text-sm font-medium text-[var(--ha-on-surface-variant)]"
          form.text_field :location_name, class: "ha-input mt-2"
        end

        div do
          form.label :body,
                     class: "text-sm font-medium text-[var(--ha-on-surface-variant)]"
          div(class: "mt-2") do
            form.rich_text_area :body, class: "ha-input"
          end
        end

        div do
          form.label :images,
                     class: "text-sm font-medium text-[var(--ha-on-surface-variant)]"
          form.file_field :images, multiple: true, accept: "image/*",
                                   direct_upload: true,
                                   class: "ha-input mt-2"
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
        class: "rounded-2xl bg-[var(--ha-error-container)] " \
               "px-5 py-4 text-sm text-[var(--ha-error)]"
      ) do
        h2(class: "font-semibold") do
          plain "#{pluralize(@entry.errors.count, "error")} " \
                "prohibited this entry from being saved:"
        end
        ul(class: "mt-2 list-disc space-y-1 pl-5") do
          @entry.errors.each do |error|
            li { error.full_message }
          end
        end
      end
    end
  end
end
