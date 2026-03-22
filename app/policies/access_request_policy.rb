# frozen_string_literal: true

class AccessRequestPolicy < ApplicationPolicy
  def index?
    superadmin?
  end

  def approve?
    superadmin?
  end

  def reject?
    superadmin?
  end
end
