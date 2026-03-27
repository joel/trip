# frozen_string_literal: true

require "rails_helper"

RSpec.describe Views::Users::Index, type: :request do
  let(:admin) { User.create!(name: "Admin", email: "admin@example.com", roles: [:superadmin]) }

  before do
    User.create!(name: "Name", email: "user-one@example.com")
    User.create!(name: "Name", email: "user-two@example.com")
    stub_current_user(admin)
  end

  it "renders a list of users" do
    get users_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("user-one@example.com")
    expect(response.body).to include("user-two@example.com")
  end
end
