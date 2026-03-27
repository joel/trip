# frozen_string_literal: true

module Views
  module JournalEntries
    class Show < Views::Base
      include Phlex::Rails::Helpers::LinkTo
      include Phlex::Rails::Helpers::ButtonTo

      def initialize(trip:, journal_entry:)
        @trip = trip
        @entry = journal_entry
      end

      def view_template
        div(class: "space-y-10") do
          render_hero_header
          render_flash_notice
          render_action_bar
          render_entry_details
          render_body if @entry.body.present?
          render_images if @entry.images.attached?
          render_reactions
          render_comments
        end
      end

      private

      def render_hero_header
        div do
          p(class: "ha-overline") { plain @trip.name }
          h1(class: "mt-2 font-headline text-4xl font-bold " \
                    "tracking-tighter md:text-5xl") do
            plain @entry.name
          end
          p(class: "mt-2 font-mono text-sm " \
                   "text-[var(--ha-on-surface-variant)]") do
            plain @entry.entry_date.to_fs(:long)
          end
        end
      end

      def render_flash_notice
        return if view_context.notice.blank?

        render Components::NoticeBanner.new(
          message: view_context.notice
        )
      end

      def render_action_bar
        div(class: "flex flex-wrap gap-3") do
          if view_context.allowed_to?(:edit?, @entry)
            link_to(
              "Edit",
              view_context.edit_trip_journal_entry_path(@trip, @entry),
              class: "ha-button ha-button-secondary"
            )
          end
          if view_context.allowed_to?(:destroy?, @entry)
            button_to(
              "Delete",
              view_context.trip_journal_entry_path(@trip, @entry),
              method: :delete,
              class: "ha-button ha-button-danger",
              form: {
                class: "inline-flex",
                data: {
                  turbo_confirm: "Delete this journal entry?"
                }
              }
            )
          end
          link_to(
            "Back to trip", view_context.trip_path(@trip),
            class: "ha-button ha-button-secondary"
          )
        end
      end

      def render_entry_details
        return if @entry.location_name.blank? && @entry.description.blank?

        div(class: "ha-card p-6") do
          if @entry.location_name.present?
            p(class: "text-sm text-[var(--ha-on-surface-variant)]") do
              plain @entry.location_name
            end
          end
          if @entry.description.present?
            p(class: "mt-3 text-lg leading-relaxed") do
              plain @entry.description
            end
          end
        end
      end

      def render_body
        div(class: "ha-card p-8 prose prose-lg dark:prose-invert " \
                   "max-w-none") do
          raw(safe(@entry.body.to_s))
        end
      end

      def render_images
        div(class: "grid grid-cols-2 gap-4 md:grid-cols-3") do
          @entry.images.each_with_index do |image, index|
            div(class: "group overflow-hidden rounded-2xl") do
              img(
                src: view_context.url_for(image),
                class: "h-full w-full object-cover " \
                       "transition-transform duration-500 " \
                       "group-hover:scale-110",
                style: "aspect-ratio: 4/3;",
                alt: "#{@entry.name} - photo #{index + 1}"
              )
            end
          end
        end
      end

      def render_reactions
        render Components::ReactionSummary.new(
          trip: @trip, journal_entry: @entry
        )
      end

      def render_comments
        div(class: "space-y-6") do
          h3(class: "font-headline text-xl font-bold") do
            plain "Comments"
          end

          div(id: "comments_#{@entry.id}", class: "space-y-4") do
            comments = @entry.comments.chronological.includes(:user)
            if comments.any?
              comments.each do |comment|
                render Components::CommentCard.new(
                  trip: @trip, journal_entry: @entry,
                  comment: comment
                )
              end
            else
              p(class: "text-sm text-[var(--ha-on-surface-variant)] " \
                       "italic") do
                plain "No comments yet."
              end
            end
          end

          render_comment_form
        end
      end

      def render_comment_form
        new_comment = @entry.comments.new(
          user: view_context.current_user
        )
        return unless view_context.allowed_to?(
          :create?, new_comment
        )

        render Components::CommentForm.new(
          trip: @trip, journal_entry: @entry,
          comment: Comment.new
        )
      end
    end
  end
end
