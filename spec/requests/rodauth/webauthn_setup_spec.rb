# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rodauth webauthn setup page" do
  let(:user) { create(:user, :superadmin) }

  before { get "/test/login", params: { user_id: user.id } }

  it "renders the Passkey name input with a UA-derived suggestion" do
    get "/webauthn-setup",
        headers: { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/120.0" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="passkey_name"')
    expect(response.body).to include('value="Mac (Chrome)"')
    expect(response.body).to include("Passkey name")
  end

  it "falls back to 'Passkey' when the user agent is empty" do
    get "/webauthn-setup", headers: { "User-Agent" => "" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('value="Passkey"')
  end
end
