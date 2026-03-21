# frozen_string_literal: true

class ApplicationPolicy < ActionPolicy::Base
  authorize :user, allow_nil: true

  private

  def superadmin?
    user&.role?(:superadmin)
  end
end
