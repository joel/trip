# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/access_requests" do
  describe "GET /request-access (public)" do
    it "renders the access request form" do
      get new_access_request_path
      expect(response).to be_successful
      expect(response.body).to include("Request Access")
    end
  end

  describe "POST /request-access (public)" do
    it "creates an access request with valid email" do
      expect do
        post submit_access_request_path, params: { access_request: { email: "new@example.com" } }
      end.to change(AccessRequest, :count).by(1)

      expect(response).to redirect_to(root_path)
    end

    it "rejects invalid email" do
      post submit_access_request_path, params: { access_request: { email: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /access_requests (superadmin)" do
    let!(:admin) { create(:user, :superadmin) }

    before { stub_current_user(admin) }

    it "renders the access requests list" do
      create(:access_request)
      get access_requests_path
      expect(response).to be_successful
    end
  end

  describe "PATCH /access_requests/:id/approve (superadmin)" do
    let!(:admin) { create(:user, :superadmin) }
    let!(:access_request) { create(:access_request) }

    before { stub_current_user(admin) }

    it "approves the request" do
      patch approve_access_request_path(access_request)
      expect(access_request.reload).to be_approved
      expect(response).to redirect_to(access_requests_path)
    end
  end

  describe "PATCH /access_requests/:id/reject (superadmin)" do
    let!(:admin) { create(:user, :superadmin) }
    let!(:access_request) { create(:access_request) }

    before { stub_current_user(admin) }

    it "rejects the request" do
      patch reject_access_request_path(access_request)
      expect(access_request.reload).to be_rejected
      expect(response).to redirect_to(access_requests_path)
    end
  end

  describe "authorization" do
    let!(:guest) { create(:user) }

    before { stub_current_user(guest) }

    it "forbids non-superadmin from index" do
      get access_requests_path
      expect(response).to have_http_status(:forbidden)
    end
  end
end
