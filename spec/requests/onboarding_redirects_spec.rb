# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onboarding redirect semantics" do
  describe "POST /login with an unknown email" do
    it "redirects with HTTP 303 See Other so non-browser clients downgrade to GET" do
      post "/login", params: { email: "ghost@example.com" }
      expect(response).to have_http_status(:see_other)
      expect(response.headers["Location"]).to end_with("/")
    end
  end

  describe "POST /create-account without a valid invitation token" do
    it "redirects with HTTP 303 See Other" do
      post "/create-account", params: { email: "anyone@example.com" }
      expect(response).to have_http_status(:see_other)
      expect(response.headers["Location"]).to end_with("/")
    end
  end
end
