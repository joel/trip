# frozen_string_literal: true

class NotificationPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def update?
    user.present? && record.recipient_id == user.id
  end

  alias mark_as_read? update?

  def mark_all_as_read?
    user.present?
  end
end
