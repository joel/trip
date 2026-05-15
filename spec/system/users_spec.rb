# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users" do
  let(:admin) { create(:user, :superadmin) }

  before { login_as(user: admin) }

  it "lists users" do
    visit users_path
    expect(page).to have_text("Users")
  end

  it "creates a new user" do
    visit new_user_path
    fill_in "Name", with: "New User"
    fill_in "Email", with: "newuser@example.com"
    click_on "Create User"
    expect(page).to have_text("User was successfully created")
  end

  it "shows user details" do
    user = create(:user, name: "Bob Detail")
    visit user_path(user)
    expect(page).to have_text("Bob Detail")
  end

  it "edits a user" do
    user = create(:user, name: "Old Name")
    visit edit_user_path(user)
    fill_in "Name", with: "New Name"
    click_on "Update User"
    expect(page).to have_text("User was successfully updated")
  end

  it "deletes a user" do
    user = create(:user, name: "Deletable User")
    visit user_path(user)
    click_on "Delete"
    expect(page).to have_text("User was successfully destroyed")
  end
end
