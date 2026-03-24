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
        div(class: "space-y-8") do
          render Components::PageHeader.new(
            section: @trip.name,
            title: @entry.name,
            subtitle: @entry.entry_date.to_fs(:long)
          ) do
            render_actions
          end

          if view_context.notice.present?
            render Components::NoticeBanner.new(
              message: view_context.notice
            )
          end

          render_entry_details
          render_body if @entry.body.present?
          render_images if @entry.images.attached?
          render_reactions
          render_comments
        end
      end

      private

      def render_actions
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
            form: { class: "inline-flex" }
          )
        end
        link_to(
          "Back to trip", view_context.trip_path(@trip),
          class: "ha-button ha-button-secondary"
        )
      end

      def render_entry_details
        div(class: "ha-card p-6") do
          if @entry.location_name.present?
            p(class: "text-sm text-[var(--ha-muted)]") do
              plain @entry.location_name
            end
          end
          if @entry.description.present?
            p(class: "mt-3 text-[var(--ha-text)]") do
              plain @entry.description
            end
          end
        end
      end

      def render_body
        div(class: "ha-card p-6 prose dark:prose-invert " \
                   "max-w-none") do
          raw(safe(@entry.body.to_s))
        end
      end

      def render_images
        div(class: "grid grid-cols-3 gap-4") do
          @entry.images.each_with_index do |image, index|
            img(
              src: view_context.url_for(image),
              class: "w-full rounded-xl",
              style: "aspect-ratio: 4/3; object-fit: cover",
              alt: "#{@entry.name} - photo #{index + 1}"
            )
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
          h3(class: "text-lg font-semibold " \
                    "text-[var(--ha-text)]") do
            plain "Comments"
          end

          div(id: "comments_#{@entry.id}",
              class: "space-y-4") do
            comments = @entry.comments.chronological
                             .includes(:user)
            if comments.any?
              comments.each do |comment|
                render Components::CommentCard.new(
                  trip: @trip, journal_entry: @entry,
                  comment: comment
                )
              end
            else
              p(class: "text-sm text-[var(--ha-muted)] " \
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
