# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WebAuthn autofill on login page" do
  it "renders the autofill form for logged-out users" do
    visit "/login"
    expect(page).to have_css(
      "#webauthn-login-form", visible: :all
    )
  end

  it "includes the autofill JavaScript" do
    visit "/login"
    expect(page).to have_css(
      "script[src*='webauthn-autofill-js']", visible: :all
    )
  end

  it "sets autocomplete with webauthn on the email field" do
    visit "/login"
    email_field = find_by_id("login", visible: :all)
    expect(email_field["autocomplete"]).to include("webauthn")
  end

  it "does not render the autofill form for logged-in users" do
    user = create(:user)
    login_as(user: user)
    visit "/"
    # Positive matcher first to confirm page loaded
    expect(page).to have_content("Welcome back")
    expect(page).to have_no_css(
      "#webauthn-login-form", visible: :all
    )
  end
end
