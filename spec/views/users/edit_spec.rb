# frozen_string_literal: true

require "rails_helper"

RSpec.describe Views::Users::Edit, type: :request do
  let(:admin) { User.create!(name: "Admin", email: "admin@example.com", roles: [:admin]) }
  let(:user) { User.create!(name: "EditUser", email: "edit-user@example.com") }

  before { stub_current_user(admin) }

  it "renders the edit user form" do
    get edit_user_path(user)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("user[name]")
    expect(response.body).to include("user[email]")
    expect(response.body).to include("user[roles][]")
  end
end
