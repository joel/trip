# frozen_string_literal: true

class InvitationsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :authorize_invitation!

  # GET /invitations (superadmin)
  def index
    @invitations = Invitation.includes(:inviter)
                             .order(created_at: :desc)
    render Views::Invitations::Index.new(invitations: @invitations)
  end

  # GET /invitations/new (superadmin)
  def new
    @invitation = Invitation.new
    render Views::Invitations::New.new(invitation: @invitation)
  end

  # POST /invitations (superadmin)
  def create
    result = Invitations::SendInvitation.new.call(params: invitation_params, user: current_user)
    case result
    in Dry::Monads::Success(invitation)
      redirect_to invitations_path, notice: "Invitation sent to #{invitation.email}."
    in Dry::Monads::Failure(errors)
      @invitation = Invitation.new(invitation_params)
      @invitation.errors.merge!(errors) if errors.respond_to?(:each)
      render Views::Invitations::New.new(invitation: @invitation),
             status: :unprocessable_content
    end
  end

  private

  def authorize_invitation!
    authorize!(@invitation || Invitation)
  end

  def invitation_params
    params.expect(invitation: [:email])
  end
end
