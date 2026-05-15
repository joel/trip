# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onboarding redirects" do
  describe "submitting the login form with an unknown email" do
    it "redirects to the home page with an invitation-required flash" do
      visit "/login"
      fill_in "Email", with: "ghost@example.com"
      click_on "Login"

      expect(page).to have_current_path("/")
      expect(page).to have_text("Invitation required")
      expect(page).to have_text("Request an invitation")
    end
  end

  describe "submitting the create-account form without an invitation token" do
    it "redirects to the home page with an invitation-required flash" do
      visit "/create-account"

      expect(page).to have_current_path("/")
      expect(page).to have_text("Invitation required")
      expect(page).to have_text("Request an invitation")
    end
  end

  describe "visiting /create-account (GET) without a valid invitation token" do
    it "redirects to the home page without ever rendering the form" do
      visit "/create-account"

      expect(page).to have_current_path("/")
      expect(page).to have_no_field("Email")
      expect(page).to have_text("Invitation required")
    end
  end

  describe "visiting /create-account (GET) with a valid invitation token" do
    let(:admin) { create(:user, :superadmin) }
    let!(:invitation) do
      create(:invitation, inviter: admin, email: "invited@example.com")
    end

    it "renders the signup form" do
      visit "/create-account?invitation_token=#{invitation.token}"

      expect(page).to have_current_path(%r{/create-account})
      expect(page).to have_field("Email", with: "invited@example.com")
      expect(page).to have_button("Create Account")
    end
  end
end
