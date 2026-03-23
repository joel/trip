# frozen_string_literal: true

module Components
  class UserCard < Components::Base
    include Phlex::Rails::Helpers::LinkTo
    include Phlex::Rails::Helpers::DOMID

    def initialize(user:)
      @user = user
    end

    def view_template
      div(id: dom_id(@user), class: "ha-card p-6") do
        div(class: "flex items-start justify-between gap-4") do
          div do
            p(class: "ha-overline") { "User" }
            p(class: "mt-2 text-lg font-semibold text-[var(--ha-text)]") { @user.name }
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
        render_actions unless view_context.action_name == "show"
      end
    end

    private

    def render_actions
      div(class: "ha-card-actions") do
        link_to("View", @user, class: "ha-button ha-button-secondary")
        link_to("Edit", view_context.edit_user_path(@user), class: "ha-button ha-button-secondary") if view_context.allowed_to?(:edit?, @user)
      end
    end
  end
end
