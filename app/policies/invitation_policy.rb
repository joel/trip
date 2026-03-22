# frozen_string_literal: true

class InvitationPolicy < ApplicationPolicy
  def index?
    superadmin?
  end

  def new?
    superadmin?
  end

  def create?
    superadmin?
  end
end
