# frozen_string_literal: true

module Components
  class InvitationCard < Components::Base
    include Phlex::Rails::Helpers::DOMID
    include Phlex::Rails::Helpers::TimeAgoInWords

    def initialize(invitation:)
      @invitation = invitation
    end

    def view_template
      div(id: dom_id(@invitation), class: "ha-card p-6") do
        div(class: "flex items-start justify-between gap-4") do
          div do
            p(class: "text-xs font-semibold uppercase tracking-[0.2em] text-[var(--ha-muted)]") do
              plain "Invitation"
            end
            p(class: "mt-2 text-lg font-semibold text-[var(--ha-text)]") { @invitation.email }
            p(class: "mt-1 text-xs text-[var(--ha-muted)]") do
              plain "Sent #{time_ago_in_words(@invitation.created_at)} ago"
              plain " by #{@invitation.inviter.name || @invitation.inviter.email}"
            end
          end
          render_status_badge
        end
      end
    end

    STATUS_BADGES = {
      "pending" => "bg-sky-100 text-sky-800 dark:bg-sky-500/10 dark:text-sky-300",
      "accepted" => "bg-emerald-100 text-emerald-800 dark:bg-emerald-500/10 dark:text-emerald-300",
      "expired" => "bg-zinc-100 text-zinc-800 dark:bg-zinc-500/10 dark:text-zinc-300"
    }.freeze

    private

    def render_status_badge
      display_status = effective_status
      css = STATUS_BADGES[display_status]

      span(class: "rounded-full px-3 py-1 text-xs font-medium #{css}") do
        plain display_status.capitalize
      end
    end

    def effective_status
      return "expired" if @invitation.pending? && @invitation.expired?

      @invitation.status
    end
  end
end
