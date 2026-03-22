# frozen_string_literal: true

class AccessRequestsController < ApplicationController
  before_action :require_authenticated_user!, only: %i[index approve reject]
  before_action :set_access_request, only: %i[approve reject]
  before_action :authorize_access_request!, only: %i[index approve reject]

  # GET /access_requests (superadmin)
  def index
    @access_requests = AccessRequest.order(created_at: :desc)
    render Views::AccessRequests::Index.new(access_requests: @access_requests)
  end

  # GET /request-access (public)
  def new
    @access_request = AccessRequest.new
    render Views::AccessRequests::New.new(access_request: @access_request)
  end

  # POST /request-access (public)
  def create
    result = AccessRequests::Submit.new.call(params: access_request_params)
    case result
    in Dry::Monads::Success
      redirect_to root_path, notice: "Your access request has been submitted. We'll be in touch!"
    in Dry::Monads::Failure(errors)
      @access_request = AccessRequest.new(access_request_params)
      @access_request.errors.merge!(errors) if errors.respond_to?(:each)
      render Views::AccessRequests::New.new(access_request: @access_request),
             status: :unprocessable_content
    end
  end

  # PATCH /access_requests/:id/approve (superadmin)
  def approve
    AccessRequests::Approve.new.call(access_request: @access_request, user: current_user)
    redirect_to access_requests_path, notice: "Access request approved."
  end

  # PATCH /access_requests/:id/reject (superadmin)
  def reject
    AccessRequests::Reject.new.call(access_request: @access_request, user: current_user)
    redirect_to access_requests_path, notice: "Access request rejected."
  end

  private

  def set_access_request
    @access_request = AccessRequest.find(params[:id])
  end

  def authorize_access_request!
    authorize!(@access_request || AccessRequest)
  end

  def access_request_params
    params.expect(access_request: [:email])
  end
end
