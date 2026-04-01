# frozen_string_literal: true

require "rails_helper"

RSpec.describe "WebAuthn autofill configuration" do
  let(:rodauth_class) { RodauthApp.rodauth }
  let(:rodauth_instance) { rodauth_class.allocate }

  it "has webauthn_autofill feature enabled" do
    expect(rodauth_class.features).to include(:webauthn_autofill)
  end

  it "enables autofill by default" do
    expect(rodauth_instance.webauthn_autofill?).to be true
  end

  it "requires resident key for new passkey registrations" do
    selection = rodauth_instance.webauthn_authenticator_selection
    expect(selection).to include(
      "residentKey" => "required",
      "requireResidentKey" => true
    )
  end
end
