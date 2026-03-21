# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    superadmin?
  end

  def show?
    superadmin?
  end

  def new?
    superadmin?
  end

  def create?
    superadmin?
  end

  def edit?
    superadmin?
  end

  def update?
    superadmin?
  end

  def destroy?
    superadmin?
  end
end
