# frozen_string_literal: true

class ApplicationPolicy < ActionPolicy::Base
  authorize :user, allow_nil: true

  private

  def admin?
    user&.role?(:admin) || user&.role?(:superadmin)
  end
end
