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
        class: "ha-card overflow-hidden ha-rise",
        data: {
          controller: "feed-entry",
          feed_entry_expanded_value: "false"
        }
      ) do
        render_cover_image if @entry.images.attached?
        div(class: "p-6") do
          render_header
          render_description if @entry.description.present?
          render_expandable_body
          render_footer
        end
      end
    end

    private

    # ── Cover image (collapsed) ──

    def render_cover_image
      div(class: "group/img relative aspect-[16/9] " \
                 "overflow-hidden") do
        img(
          src: view_context.url_for(@entry.images.first),
          class: "h-full w-full object-cover " \
                 "transition-transform duration-700 " \
                 "group-hover/img:scale-105",
          alt: @entry.name,
          loading: "lazy"
        )
      end
    end

    # ── Header: date · title · location · author + actions ──

    def render_header
      div(class: "flex items-start gap-4") do
        div(class: "flex-1 min-w-0") do
          p(class: "ha-overline") do
            plain @entry.entry_date.strftime("%B %d, %Y").upcase
          end
          h3(class: "mt-1 font-headline text-xl " \
                    "font-bold tracking-tight") do
            plain @entry.name
          end
          render_meta_line
        end
        render_header_actions
      end
    end

    def render_meta_line
      div(class: "mt-2 flex flex-wrap items-center " \
                 "gap-x-3 gap-y-1 text-xs " \
                 "text-[var(--ha-on-surface-variant)]") do
        if @entry.location_name.present?
          span(class: "inline-flex items-center gap-1") do
            plain "\u{1F4CD}"
            plain @entry.location_name
          end
        end
        if @entry.author
          span(class: "inline-flex items-center gap-1") do
            span(
              class: "inline-flex h-5 w-5 items-center " \
                     "justify-center rounded-full " \
                     "bg-[var(--ha-surface-high)] " \
                     "text-[10px] font-semibold " \
                     "text-[var(--ha-on-surface-variant)]"
            ) { plain initials(@entry.author) }
            plain @entry.author.name
          end
        end
      end
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

    # ── Description (collapsed, clamped) ──

    def render_description
      p(class: "mt-3 text-sm leading-relaxed " \
               "text-[var(--ha-on-surface-variant)] " \
               "line-clamp-2") do
        plain @entry.description
      end
    end

    # ── Expandable body ──

    def render_expandable_body
      div(
        class: "mt-4",
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
      p(class: "text-sm leading-relaxed text-[var(--ha-on-surface-variant)] mb-4") { plain @entry.description }
    end

    def render_body
      div(class: "prose prose-lg dark:prose-invert max-w-none mb-6") { raw(safe(@entry.body.to_s)) }
    end

    def render_images
      div(class: "grid grid-cols-2 gap-3 mb-6 " \
                 "md:grid-cols-3") do
        @entry.images.each_with_index do |image, idx|
          div(class: "group/photo overflow-hidden " \
                     "rounded-xl") do
            img(
              src: view_context.url_for(image),
              class: "h-full w-full object-cover " \
                     "transition-transform duration-500 " \
                     "group-hover/photo:scale-110",
              style: "aspect-ratio: 4/3;",
              alt: "#{@entry.name} — photo #{idx + 1}",
              loading: "lazy"
            )
          end
        end
      end
    end

    def render_reactions
      render Components::ReactionSummary.new(trip: @trip, journal_entry: @entry)
    end

    def render_comments
      div(class: "mt-6") do
        render_comments_header
        div(id: "comments_#{@entry.id}", class: "mt-4 space-y-3") do
          comments = @entry.comments.chronological
          if comments.any?
            comments.each do |comment|
              render Components::CommentCard.new(
                trip: @trip, journal_entry: @entry,
                comment: comment
              )
            end
          else
            p(class: "text-sm italic " \
                     "text-[var(--ha-on-surface-variant)]") do
              plain "No comments yet."
            end
          end
        end
        render_comment_form
      end
    end

    def render_comments_header
      count = @entry.comments.count
      div(class: "flex items-center gap-3") do
        h4(class: "font-headline text-base font-semibold") do
          plain "Comments"
          span(class: "ml-1 text-sm font-normal text-[var(--ha-on-surface-variant)]") { plain "(#{count})" } if count.positive?
        end
        div(class: "flex-1 h-px bg-[var(--ha-surface-high)]")
      end
    end

    def render_comment_form
      new_comment = @entry.comments.new(
        user: view_context.current_user
      )
      return unless view_context.allowed_to?(
        :create?, new_comment
      )

      div(class: "mt-4") do
        render Components::CommentForm.new(
          trip: @trip, journal_entry: @entry,
          comment: Comment.new
        )
      end
    end

    def render_expanded_actions
      return unless view_context.allowed_to?(:destroy?, @entry)

      div(class: "mt-6 pt-4 border-t " \
                 "border-[var(--ha-surface-high)]") do
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

    # ── Footer (delegated to JournalEntryFooter) ──

    def render_footer
      render Components::JournalEntryFooter.new(
        journal_entry: @entry
      )
    end

    # ── Helpers ──

    def initials(user)
      return "?" unless user&.name

      user.name.split.first(2).pluck(0).join.upcase
    end
  end
end
