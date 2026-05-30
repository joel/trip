# frozen_string_literal: true

module Components
  # One row in the trip Activity feed, styled to the Google Stitch
  # "Trip Activity Feed" reference: an avatar timeline node + a short
  # connector, a bold-actor summary, an optional inset diff block,
  # optional state-change chips, and a meta line (relative time +
  # source badge). Renders entirely from the denormalised AuditLog
  # columns (no association loads), so it stays correct after the
  # trip/actor/target is deleted.
  class AuditLogCard < Components::Base
    include Phlex::Rails::Helpers::DOMID
    include Phlex::Rails::Helpers::TimeAgoInWords
    include Phlex::Rails::Helpers::ButtonTo

    SOURCE_BADGES = {
      "mcp" => "Agent", "telegram" => "Telegram", "system" => "System"
    }.freeze

    # restorable maps auditable_id => the currently-discarded record the viewer
    # may restore (computed + authorised in the controller). Defaults to {} so
    # the live-stream render path (RecordAuditLogJob) is unaffected.
    def initialize(audit_log:, restorable: {})
      @log = audit_log
      @restorable = restorable
    end

    def view_template
      div(id: dom_id(@log), class: row_css) do
        render_rail
        div(class: "flex-1 min-w-0 pb-2") do
          render_summary
          render_changes if changes.present?
          render_state_change if state_change?
          render_meta
          render_restore if restorable_record
        end
      end
    end

    private

    # Only a deletion row offers restore. Without this gate every row sharing
    # this auditable_id (created/updated/restored/…) would show the button,
    # because @restorable is keyed by auditable_id, not by event.
    def restorable_record
      return nil unless @log.action.to_s.end_with?(".deleted")

      @restorable[@log.auditable_id]
    end

    def render_restore
      button_to(
        "Restore",
        restore_path(restorable_record),
        method: :patch,
        class: "mt-3 ha-button ha-button-secondary text-xs",
        form: { class: "inline-flex" }
      )
    end

    def restore_path(record)
      case record
      when Trip
        view_context.restore_trip_path(record)
      when JournalEntry
        view_context.restore_trip_journal_entry_path(record.trip_id, record)
      when Comment
        view_context.restore_trip_journal_entry_comment_path(
          @log.trip_id, record.journal_entry_id, record
        )
      end
    end

    def row_css
      base = "relative flex gap-4 group"
      return base unless @log.low_signal?

      "#{base} opacity-60 hover:opacity-100 " \
        "motion-safe:transition-opacity motion-safe:duration-200"
    end

    # The avatar is the timeline node; the connector falls through to
    # the next row's node, forming the rail.
    def render_rail
      div(class: "flex flex-col items-center gap-2 flex-shrink-0") do
        div(class: "w-10 h-10 rounded-full flex items-center " \
                   "justify-center ha-gradient-aura text-xs " \
                   "font-bold text-white") { plain initials }
        div(class: "w-1 flex-1 rounded-full bg-[var(--ha-border)]")
      end
    end

    def render_summary
      p(class: "text-sm text-[var(--ha-text)] leading-snug") do
        if bold_actor?
          span(class: "font-semibold") { plain @log.actor_label }
          plain @log.summary[@log.actor_label.length..]
        else
          plain @log.summary
        end
      end
    end

    def render_changes
      div(class: "mt-2 rounded-2xl bg-[var(--ha-surface-low)] " \
                 "p-4 space-y-1") do
        changes.first(5).each do |field, (old, new)|
          div(class: "text-xs flex flex-wrap items-center gap-1") do
            span(class: "font-semibold " \
                        "text-[var(--ha-on-surface-variant)]") do
              plain "#{field.to_s.humanize}:"
            end
            span(class: "line-through text-[var(--ha-danger)]") do
              plain clip(old)
            end
            span(class: "text-[var(--ha-on-surface-variant)]") do
              plain "→"
            end
            span(class: "text-[var(--ha-primary)]") { plain clip(new) }
          end
        end
      end
    end

    def render_state_change
      div(class: "mt-2 flex items-center gap-2") do
        state_chip(meta["from_state"], muted: true)
        span(class: "text-xs text-[var(--ha-muted)]") { plain "→" }
        state_chip(meta["to_state"], muted: false)
      end
    end

    def state_chip(value, muted:)
      tone = if muted
               "bg-[var(--ha-surface-container)] " \
                 "text-[var(--ha-on-surface-variant)]"
             else
               "bg-[var(--ha-primary)]/10 text-[var(--ha-primary)]"
             end
      span(class: "text-[10px] font-bold uppercase tracking-wider " \
                  "px-2 py-0.5 rounded-full #{tone}") do
        plain value.to_s.humanize
      end
    end

    def render_meta
      div(class: "flex items-center gap-3 mt-2") do
        span(class: "text-[11px] font-medium uppercase " \
                    "tracking-wider text-[var(--ha-muted)]") do
          plain "#{time_ago_in_words(@log.occurred_at)} ago"
        end
        render_source_badge if source_badge
      end
    end

    def render_source_badge
      span(class: "text-[10px] font-bold uppercase tracking-wider " \
                  "px-2 py-0.5 rounded-full " \
                  "bg-[var(--ha-primary)]/10 text-[var(--ha-primary)]") do
        plain source_badge
      end
    end

    def meta
      @meta ||= @log.metadata.is_a?(Hash) ? @log.metadata : {}
    end

    def changes
      meta["changes"]
    end

    def state_change?
      meta["from_state"].present? && meta["to_state"].present?
    end

    def bold_actor?
      @log.actor_label.present? &&
        @log.summary.to_s.start_with?(@log.actor_label.to_s)
    end

    def source_badge
      SOURCE_BADGES[@log.source.to_s]
    end

    def initials
      @log.actor_label.to_s.split.map(&:first).first(2).join.upcase
          .presence || "?"
    end

    def clip(value)
      str = value.to_s
      str.length > 60 ? "#{str[0, 57]}..." : str
    end
  end
end
