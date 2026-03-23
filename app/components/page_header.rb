# frozen_string_literal: true

module Components
  class PageHeader < Components::Base
    def initialize(section:, title:, subtitle: nil)
      @section = section
      @title = title
      @subtitle = subtitle
    end

    def view_template(&block)
      div(class: "flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between") do
        div do
          p(class: "ha-overline") { @section }
          h1(class: "mt-2 text-3xl font-semibold tracking-tight sm:text-4xl") { @title }
          p(class: "mt-2 text-sm text-[var(--ha-muted)]") { @subtitle } if @subtitle
        end
        div(class: "flex flex-wrap gap-2", &block) if block
      end
    end
  end
end
