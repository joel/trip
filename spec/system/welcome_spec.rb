# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Welcome" do
  it "renders the home page for visitors" do
    visit root_path
    expect(page).to have_content("Welcome to Catalyst")
    expect(page).to have_content("Request an invitation")
    expect(page).to have_link("Request Access")
    expect(page).to have_no_content("Returning?")
  end

  context "when logged in" do
    let(:admin) { create(:user, :superadmin, name: "Joel Azemar") }

    before { login_as(user: admin) }

    it "renders the home page for authenticated users" do
      visit root_path
      expect(page).to have_content("Welcome back")
      expect(page).to have_content("New Trip")
    end
  end
end
