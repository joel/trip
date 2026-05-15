# frozen_string_literal: true

module Components
  # One row in the trip Activity feed. Renders entirely from the
  # denormalised AuditLog columns (no association loads), so it stays
  # correct after the trip/actor/target is deleted.
  class AuditLogCard < Components::Base
    include Phlex::Rails::Helpers::DOMID
    include Phlex::Rails::Helpers::TimeAgoInWords

    SOURCE_BADGES = {
      "mcp" => "Agent", "telegram" => "Telegram", "system" => "System"
    }.freeze

    def initialize(audit_log:)
      @log = audit_log
    end

    def view_template
      div(id: dom_id(@log), class: card_css) do
        render_avatar
        div(class: "flex-1 min-w-0") do
          render_summary
          render_changes if changes.present?
          render_meta
        end
      end
    end

    private

    def card_css
      base = "rounded-2xl p-4 flex items-start gap-4 " \
             "motion-safe:transition-colors motion-safe:duration-200 " \
             "bg-[var(--ha-surface-low)] " \
             "hover:bg-[var(--ha-surface-container)]"
      @log.low_signal? ? "#{base} opacity-60 hover:opacity-100" : base
    end

    def render_avatar
      div(class: "w-10 h-10 rounded-2xl flex-shrink-0 flex " \
                 "items-center justify-center ha-gradient-aura " \
                 "text-xs font-bold text-white") do
        plain initials
      end
    end

    def render_summary
      p(class: "text-sm text-[var(--ha-text)] leading-snug") do
        plain @log.summary
      end
    end

    def render_changes
      div(class: "mt-2 space-y-1") do
        changes.first(5).each do |field, (old, new)|
          div(class: "text-xs flex flex-wrap items-center gap-1") do
            span(class: "font-semibold text-[var(--ha-on-surface-variant)]") do
              plain "#{field.to_s.humanize}:"
            end
            span(class: "line-through text-[var(--ha-danger)]") do
              plain clip(old)
            end
            span(class: "text-[var(--ha-on-surface-variant)]") { plain "→" }
            span(class: "text-[var(--ha-primary)]") { plain clip(new) }
          end
        end
      end
    end

    def render_meta
      div(class: "flex items-center gap-3 mt-2") do
        span(class: "text-[11px] font-medium text-[var(--ha-muted)]") do
          plain "#{time_ago_in_words(@log.occurred_at)} ago"
        end
        render_source_badge if source_badge
      end
    end

    def render_source_badge
      span(class: "text-[10px] font-bold uppercase tracking-wider " \
                  "px-2 py-0.5 rounded-full " \
                  "bg-[var(--ha-primary)]/10 " \
                  "text-[var(--ha-primary)]") do
        plain source_badge
      end
    end

    def changes
      @log.metadata.is_a?(Hash) ? @log.metadata["changes"] : nil
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
