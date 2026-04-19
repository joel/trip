# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rodauth webauthn remove page" do
  let(:user) { create(:user, :superadmin) }

  before do
    seed_passkey(user, webauthn_id: "key-1", name: "Mac fingerprint")
    seed_passkey(user, webauthn_id: "key-2", name: nil)
    get "/test/login", params: { user_id: user.id }
  end

  def seed_passkey(user, webauthn_id:, name:)
    ActiveRecord::Base.connection.exec_insert(
      "INSERT INTO user_webauthn_keys " \
      "(user_id, webauthn_id, public_key, sign_count, last_use, name) " \
      "VALUES (?, ?, ?, ?, ?, ?)",
      "seed_passkey",
      [user.id, webauthn_id, "pub-#{webauthn_id}", 0, Time.current.iso8601, name]
    )
  end

  it "shows the named passkey and falls back to 'Passkey' for unnamed rows" do
    get "/webauthn-remove"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Mac fingerprint")
    expect(response.body).to include("Passkey")
    expect(response.body).to match(/Last used:/)
  end

  it "renders an Add passkey link pointing at /webauthn-setup" do
    get "/webauthn-remove"

    expect(response.body).to include("Add another passkey")
    expect(response.body).to match(%r{href="/webauthn-setup"[^>]*>\s*Add passkey}m)
  end
end
