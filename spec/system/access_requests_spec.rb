# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Access Requests" do
  it "allows a visitor to submit an access request" do
    visit new_access_request_path
    fill_in "Email", with: "visitor@example.com"
    click_on "Request Access"
    expect(page).to have_content("Your access request has been submitted")
  end

  context "when logged in as superadmin" do
    let(:admin) { create(:user, :superadmin) }

    before { login_as(user: admin) }

    it "lists access requests" do
      AccessRequest.create!(email: "pending@example.com")
      visit access_requests_path
      expect(page).to have_content("pending@example.com")
    end
  end
end
