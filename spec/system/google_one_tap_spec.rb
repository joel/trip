# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Google One Tap" do
  context "when GOOGLE_CLIENT_ID is configured" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID")
                                .and_return("test-client-id")
    end

    it "renders the One Tap controller div for logged-out users" do
      visit "/"
      expect(page).to have_css(
        "[data-controller='google-one-tap']", visible: :all
      )
    end

    it "does not render the One Tap controller div for logged-in users" do
      user = create(:user)
      login_as(user: user)
      visit "/"
      # Assert page loaded first (positive matcher), then check absence
      expect(page).to have_content("Welcome back")
      expect(page).to have_no_css(
        "[data-controller='google-one-tap']", visible: :all
      )
    end
  end

  context "when GOOGLE_CLIENT_ID is not configured" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID")
                                .and_return(nil)
    end

    it "does not render the One Tap controller div" do
      visit "/"
      # Assert page loaded first (positive matcher), then check absence
      expect(page).to have_content("Welcome to Catalyst")
      expect(page).to have_no_css(
        "[data-controller='google-one-tap']", visible: :all
      )
    end
  end
end
