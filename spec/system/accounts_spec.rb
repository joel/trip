# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Accounts" do
  let(:admin) { create(:user, :superadmin, name: "Alice Test") }

  before { login_as(user: admin) }

  it "shows account details" do
    visit account_path
    expect(page).to have_text("My account")
    expect(page).to have_text("Alice Test")
  end

  it "navigates to edit account" do
    visit account_path
    click_on "Edit account"
    expect(page).to have_text("Edit account")
  end

  it "updates account name" do
    visit edit_account_path
    fill_in "Name", with: "Alice Updated"
    click_on "Save changes"
    expect(page).to have_text("Alice Updated")
  end

  it "signs the user out from the account page" do
    visit account_path
    within("main") do
      expect(page).to have_button("Sign out")
      click_on "Sign out"
    end
    expect(page).to have_text("Welcome to Catalyst")
  end
end
