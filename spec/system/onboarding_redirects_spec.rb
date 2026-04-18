# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onboarding redirects" do
  describe "submitting the login form with an unknown email" do
    it "redirects to the home page with an invitation-required flash" do
      visit "/login"
      fill_in "Email", with: "ghost@example.com"
      click_on "Login"

      expect(page).to have_current_path("/")
      expect(page).to have_content("Invitation required")
      expect(page).to have_content("Request an invitation")
    end
  end
end
