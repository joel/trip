# frozen_string_literal: true

require "rails_helper"

RSpec.describe Views::Welcome::Home, type: :request do
  it "renders the home page" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Welcome home")
  end
end
