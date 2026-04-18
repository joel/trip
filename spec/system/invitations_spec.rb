# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invitations" do
  describe "superadmin management" do
    let(:admin) { create(:user, :superadmin) }

    before { login_as(user: admin) }

    it "allows superadmin to send an invitation" do
      visit new_invitation_path
      fill_in "Email", with: "invitee@example.com"
      click_on "Send Invitation"
      expect(page).to have_content("Invitation sent to invitee@example.com")
    end

    it "lists sent invitations" do
      create(:invitation, inviter: admin, email: "listed@example.com")
      visit invitations_path
      expect(page).to have_content("listed@example.com")
    end
  end

  describe "accepting an invitation via /create-account" do
    let(:admin) { create(:user, :superadmin) }
    let!(:invitation) do
      create(:invitation, inviter: admin, email: "new-invitee@example.com")
    end

    it "creates a verified account, auto-logs the user in, and sends no verify email" do
      ActionMailer::Base.deliveries.clear

      visit "/create-account?invitation_token=#{invitation.token}"
      click_on "Create Account"

      expect(page).to have_current_path("/")

      user = User.find_by(email: "new-invitee@example.com")
      expect(user).not_to be_nil
      expect(user.status).to eq(2)

      expect(invitation.reload).to be_accepted

      verify_subjects = ActionMailer::Base.deliveries.map(&:subject)
      expect(verify_subjects).not_to include(match(/verify/i))
    end
  end
end
