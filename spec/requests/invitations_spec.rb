# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/invitations" do
  let!(:admin) { create(:user, :superadmin) }

  before { stub_current_user(admin) }

  describe "GET /invitations" do
    it "renders the invitations list" do
      create(:invitation, inviter: admin)
      get invitations_path
      expect(response).to be_successful
    end
  end

  describe "GET /invitations/new" do
    it "renders the new invitation form" do
      get new_invitation_path
      expect(response).to be_successful
      expect(response.body).to include("Send Invitation")
    end
  end

  describe "POST /invitations" do
    it "creates an invitation with valid email" do
      expect do
        post invitations_path, params: { invitation: { email: "invitee@example.com" } }
      end.to change(Invitation, :count).by(1)

      expect(response).to redirect_to(invitations_path)
    end

    it "rejects invalid email" do
      post invitations_path, params: { invitation: { email: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "authorization" do
    let!(:guest) { create(:user) }

    before { stub_current_user(guest) }

    it "forbids non-superadmin from index" do
      get invitations_path
      expect(response).to have_http_status(:forbidden)
    end
  end
end
