# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Accounts" do
  let(:admin) { create(:user, :superadmin, name: "Alice Test") }

  before { login_as(user: admin) }

  it "shows account details" do
    visit account_path
    expect(page).to have_content("My account")
    expect(page).to have_content("Alice Test")
  end

  it "navigates to edit account" do
    visit account_path
    click_on "Edit account"
    expect(page).to have_content("Edit account")
  end

  it "updates account name" do
    visit edit_account_path
    fill_in "Name", with: "Alice Updated"
    click_on "Save changes"
    expect(page).to have_content("Alice Updated")
  end
end
