# frozen_string_literal: true

require "rails_helper"

RSpec.describe Views::Users::Show, type: :request do
  let(:admin) { User.create!(name: "Admin", email: "admin@example.com", roles: [:superadmin]) }
  let(:user) { User.create!(name: "TestUser", email: "show-user@example.com") }

  before { stub_current_user(admin) }

  it "renders user attributes" do
    get user_path(user)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("TestUser")
  end
end
