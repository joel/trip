# frozen_string_literal: true

module Components
  class JournalEntryCard < Components::Base
    include Phlex::Rails::Helpers::LinkTo
    include Phlex::Rails::Helpers::ButtonTo
    include Phlex::Rails::Helpers::DOMID

    def initialize(trip:, journal_entry:)
      @trip = trip
      @entry = journal_entry
    end

    def view_template
      article(
        id: dom_id(@entry),
        class: "ha-card overflow-hidden",
        data: {
          controller: "feed-entry",
          feed_entry_expanded_value: "false"
        }
      ) do
        render_header
        render_image_preview if @entry.images.attached?
        render_description if @entry.description.present?
        render_expandable_body
        render_footer
      end
    end

    private

    def render_header
      div(class: "p-6 pb-0") do
        div(class: "flex items-start gap-4") do
          div(class: "flex-1 min-w-0") do
            p(class: "ha-overline") do
              plain @entry.entry_date.to_fs(:long)
            end
            h3(class: "mt-1 font-headline text-xl " \
                      "font-bold tracking-tight") do
              plain @entry.name
            end
            render_location if @entry.location_name.present?
            render_author
          end
          render_header_actions
        end
      end
    end

    def render_location
      p(class: "mt-1 text-xs text-[var(--ha-on-surface-variant)]") { plain @entry.location_name }
    end

    def render_author
      p(class: "mt-1 text-xs text-[var(--ha-on-surface-variant)]") { plain @entry.author&.name }
    end

    def render_header_actions
      div(class: "flex shrink-0 items-center gap-2") do
        render_mute_toggle
        if view_context.allowed_to?(:edit?, @entry)
          link_to(
            "Edit",
            view_context.edit_trip_journal_entry_path(
              @trip, @entry
            ),
            class: "text-xs font-medium " \
                   "text-[var(--ha-on-surface-variant)] " \
                   "hover:text-[var(--ha-primary)]",
            title: "Edit entry"
          )
        end
      end
    end

    def render_mute_toggle
      return unless view_context.current_user

      subscribed = @entry.journal_entry_subscriptions
                         .any? { |s| s.user_id == view_context.current_user.id }
      render Components::JournalEntryFollowButton.new(
        trip: @trip, journal_entry: @entry,
        subscribed: subscribed
      )
    end

    def render_image_preview
      div(class: "mx-6 mt-4 relative aspect-[16/9] " \
                 "overflow-hidden rounded-2xl") do
        img(
          src: view_context.url_for(@entry.images.first),
          class: "h-full w-full object-cover",
          alt: @entry.name
        )
      end
    end

    def render_description
      p(class: "mx-6 mt-3 text-sm " \
               "text-[var(--ha-on-surface-variant)] " \
               "line-clamp-2") do
        plain @entry.description
      end
    end

    def render_expandable_body
      div(
        class: "px-6 mt-4",
        data: { feed_entry_target: "body" },
        hidden: true
      ) do
        render_full_description if @entry.description.present?
        render_body if @entry.body.present?
        render_images if @entry.images.attached?
        render_reactions
        render_comments
        render_expanded_actions
      end
    end

    def render_full_description
      p(class: "text-base leading-relaxed mb-4") { plain @entry.description }
    end

    def render_body
      div(class: "prose prose-lg dark:prose-invert max-w-none mb-6") { raw(safe(@entry.body.to_s)) }
    end

    def render_images
      div(class: "grid grid-cols-2 gap-3 mb-6 " \
                 "md:grid-cols-3") do
        @entry.images.each_with_index do |image, index|
          div(class: "overflow-hidden rounded-xl") do
            img(
              src: view_context.url_for(image),
              class: "h-full w-full object-cover",
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
      div(class: "mt-6 space-y-4") do
        h4(class: "font-headline text-lg font-semibold") do
          count = @entry.comments.count
          plain "Comments (#{count})"
        end

        div(id: "comments_#{@entry.id}", class: "space-y-3") do
          comments = @entry.comments.chronological
          if comments.any?
            comments.each do |comment|
              render Components::CommentCard.new(
                trip: @trip, journal_entry: @entry,
                comment: comment
              )
            end
          else
            p(class: "text-sm " \
                     "text-[var(--ha-on-surface-variant)] " \
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

    def render_expanded_actions
      return unless view_context.allowed_to?(:destroy?, @entry)

      div(class: "mt-6 flex gap-3") do
        button_to(
          "Delete",
          view_context.trip_journal_entry_path(@trip, @entry),
          method: :delete,
          class: "ha-button ha-button-danger text-sm",
          form: {
            class: "inline-flex",
            data: {
              turbo_confirm: "Delete this journal entry?"
            }
          }
        )
      end
    end

    def render_footer
      div(class: "px-6 py-4 mt-2 flex items-center " \
                 "justify-between border-t " \
                 "border-[var(--ha-border)]") do
        render_footer_stats
        render_toggle_button
      end
    end

    def render_footer_stats
      div(class: "flex items-center gap-4 text-xs " \
                 "text-[var(--ha-on-surface-variant)]") do
        render_reaction_count
        render_comment_count
      end
    end

    def render_reaction_count
      count = @entry.reactions.count
      return unless count.positive?

      span(id: "reaction_count_#{@entry.id}") do
        plain "#{count} reaction#{"s" if count != 1}"
      end
    end

    def render_comment_count
      count = @entry.comments.count
      return unless count.positive?

      span do
        plain "#{count} comment#{"s" if count != 1}"
      end
    end

    def render_toggle_button
      button(
        class: "inline-flex items-center gap-1 text-sm " \
               "font-semibold text-[var(--ha-primary)] " \
               "cursor-pointer",
        data: { action: "feed-entry#toggle" }
      ) do
        span(data: { feed_entry_target: "label" }) do
          plain "Read more"
        end
      end
    end
  end
end
