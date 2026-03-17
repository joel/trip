# frozen_string_literal: true

class TestSessionsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    raise ActionController::RoutingError, "Not Found" unless Rails.env.test?

    user = find_user
    user.update!(status: rodauth.account_open_status_value)
    session[rodauth.session_key] = user.id
    session[rodauth.authenticated_by_session_key] = ["test"]

    head :ok
  end

  private

  def find_user
    return User.find(params[:user_id]) if params[:user_id].present?
    return User.find_by!(email: params[:email]) if params[:email].present?

    raise ActionController::BadRequest, "Missing user_id or email"
  end
end
