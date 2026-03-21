# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users" do
  let(:admin) { create(:user, :superadmin) }

  before { login_as(user: admin) }

  it "lists users" do
    visit users_path
    expect(page).to have_content("Users")
  end

  it "creates a new user" do
    visit new_user_path
    fill_in "Name", with: "New User"
    fill_in "Email", with: "newuser@example.com"
    click_on "Create User"
    expect(page).to have_content("User was successfully created")
  end
end
