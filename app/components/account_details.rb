# frozen_string_literal: true

module Components
  class AccountDetails < Components::Base
    def initialize(user:)
      @user = user
    end

    def view_template
      div(class: "ha-card p-6") do
        div(class: "flex flex-wrap items-start justify-between gap-4") do
          div do
            p(class: "ha-overline") { "Account" }
            p(class: "mt-2 text-lg font-semibold text-[var(--ha-text)]") do
              plain(@user.name.presence || "Unnamed")
            end
            div(class: "mt-3 flex items-center gap-2 text-xs text-[var(--ha-muted)]") do
              span(class: "rounded-full bg-[var(--ha-surface-muted)] px-2 py-1") { "Email" }
              span(class: "font-semibold text-[var(--ha-text)]") { @user.email }
            end
          end
          span(
            class: "rounded-full border border-[var(--ha-border)] bg-[var(--ha-surface-muted)] " \
                   "px-3 py-1 text-xs font-medium text-[var(--ha-muted)]"
          ) do
            plain "##{@user.id}"
          end
        end
      end
    end
  end
end
