# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invitations" do
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
