# frozen_string_literal: true

module Components
  class TripCard < Components::Base
    include Phlex::Rails::Helpers::LinkTo
    include Phlex::Rails::Helpers::DOMID

    def initialize(trip:)
      @trip = trip
    end

    def view_template
      cancelled_css = "grayscale opacity-80 hover:grayscale-0 hover:opacity-100"
      div(id: dom_id(@trip),
          class: "group relative overflow-hidden rounded-[2rem] " \
                 "bg-[var(--ha-card)] shadow-[var(--ha-card-shadow)] " \
                 "transition-all duration-500 " \
                 "hover:-translate-y-1 hover:shadow-[var(--ha-card-shadow-hover)] " \
                 "#{cancelled_css if cancelled?}") do
        render_cover_image
        render_content
      end
    end

    private

    def render_cover_image
      div(class: "relative aspect-[16/10] overflow-hidden " \
                 "bg-gradient-to-br from-[var(--ha-primary)] " \
                 "to-[var(--ha-primary-container)]") do
        div(class: "absolute inset-0 bg-gradient-to-t " \
                   "from-black/20 to-transparent")
        div(class: "absolute top-5 left-5 z-10") do
          render Components::TripStateBadge.new(state: @trip.state)
        end
      end
    end

    def render_content
      div(class: "p-8") do
        h3(class: "font-headline text-xl font-bold tracking-tight") do
          plain @trip.name
        end
        render_dates if @trip.effective_start_date
        render_description if @trip.description.present?
        render_footer
      end
    end

    def render_dates
      p(class: "mt-2 font-mono text-xs " \
               "text-[var(--ha-on-surface-variant)]") do
        plain @trip.effective_start_date&.to_fs(:long)
        plain " — #{@trip.effective_end_date.to_fs(:long)}" if @trip.effective_end_date
      end
    end

    def render_description
      p(class: "mt-3 text-sm text-[var(--ha-on-surface-variant)] " \
               "line-clamp-2") do
        plain @trip.description
      end
    end

    def render_footer
      div(class: "mt-6 flex items-center justify-between") do
        link_to(
          view_context.trip_path(@trip),
          class: "inline-flex items-center gap-1 text-sm font-semibold " \
                 "text-[var(--ha-primary)] transition-all " \
                 "group-hover:gap-2"
        ) do
          plain "View details"
          span(class: "transition-transform group-hover:translate-x-0.5") do
            plain " \u2192"
          end
        end
        if view_context.allowed_to?(:edit?, @trip)
          link_to("Edit", view_context.edit_trip_path(@trip),
                  class: "text-sm font-medium " \
                         "text-[var(--ha-on-surface-variant)] " \
                         "hover:text-[var(--ha-primary)]")
        end
      end
    end

    def cancelled? = @trip.state.to_s == "cancelled"
  end
end
