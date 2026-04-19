# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Passkey management surface" do
  let(:user) { create(:user, :superadmin) }

  before { login_as(user: user) }

  def seed_passkey(user, webauthn_id: SecureRandom.uuid, name: nil)
    conn = ActiveRecord::Base.connection
    columns = %w[user_id webauthn_id public_key sign_count last_use]
    values = [user.id, webauthn_id, "stub-public-key", 0, Time.current.iso8601]
    if conn.columns("user_webauthn_keys").any? { |c| c.name == "name" }
      columns << "name"
      values << name
    end
    placeholders = columns.map { "?" }.join(", ")
    sql = "INSERT INTO user_webauthn_keys (#{columns.join(", ")}) VALUES (#{placeholders})"
    conn.exec_insert(sql, "seed_passkey", values)
  end

  context "when the user has no passkeys registered" do
    it "shows the Add passkey link in the sidebar and hides Manage passkeys" do
      visit root_path
      within("nav[aria-label='Main navigation']") do
        expect(page).to have_link("Add passkey")
        expect(page).to have_no_link("Manage passkeys")
      end
    end
  end

  context "when the user has at least one passkey registered" do
    before { seed_passkey(user) }

    it "shows the Manage passkeys link and hides Add passkey in the sidebar" do
      visit root_path
      within("nav[aria-label='Main navigation']") do
        expect(page).to have_link("Manage passkeys")
        expect(page).to have_no_link("Add passkey")
      end
    end
  end
end
