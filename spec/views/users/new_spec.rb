# frozen_string_literal: true

require "rails_helper"

RSpec.describe Views::Users::New, type: :request do
  let(:admin) { User.create!(name: "Admin", email: "admin@example.com", roles: [:admin]) }

  before { stub_current_user(admin) }

  it "renders new user form" do
    get new_user_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("user[name]")
    expect(response.body).to include("user[email]")
    expect(response.body).to include("user[roles][]")
  end
end
