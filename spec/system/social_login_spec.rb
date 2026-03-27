# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Social Login" do
  context "when GOOGLE_CLIENT_ID is not configured" do
    it "does not show Google button on login page" do
      allow(ENV).to receive(:fetch)
        .and_call_original
      allow(ENV).to receive(:[])
        .and_call_original
      allow(ENV).to receive(:[])
        .with("GOOGLE_CLIENT_ID").and_return(nil)

      visit "/login"
      expect(page).to have_content("Sign in")
      expect(page).to have_no_button("Sign in with Google")
    end
  end
end
