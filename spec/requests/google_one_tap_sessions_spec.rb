# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /auth/google/one_tap" do
  let(:user) { create(:user, email: "jane@example.com", name: nil) }
  let(:google_uid) { "google-uid-#{SecureRandom.hex(4)}" }
  let(:google_payload) do
    {
      "sub" => google_uid,
      "email" => user.email,
      "email_verified" => "true",
      "name" => "Jane Doe",
      "aud" => "test-google-client-id"
    }
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).with("GOOGLE_CLIENT_ID")
                              .and_return("test-google-client-id")

    stub_google_tokeninfo(google_payload)
  end

  context "with existing OmniAuth identity" do
    before { insert_identity(user, google_uid) }

    it "logs in the user" do
      post "/auth/google/one_tap",
           params: { credential: "valid-jwt" },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("ok" => true)
    end
  end

  context "with matching email but no identity" do
    it "creates the identity and logs in" do
      expect do
        post "/auth/google/one_tap",
             params: { credential: "valid-jwt" },
             as: :json
      end.to change {
        identity_count(google_uid)
      }.from(0).to(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("ok" => true)
    end
  end

  context "with no matching account" do
    before do
      stub_google_tokeninfo(
        google_payload.merge("email" => "unknown@example.com")
      )
    end

    it "returns no_account error with redirect" do
      post "/auth/google/one_tap",
           params: { credential: "valid-jwt" },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body["error"]).to eq("no_account")
      expect(body["redirect"]).to eq("/request-access")
    end
  end

  context "with inactive account" do
    before do
      user.update!(status: 3) # closed/locked
      insert_identity(user, google_uid)
    end

    it "returns account_not_active error" do
      post "/auth/google/one_tap",
           params: { credential: "valid-jwt" },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("account_not_active")
    end
  end

  context "with invalid token" do
    before do
      mock_response = instance_double(Net::HTTPBadRequest)
      allow(mock_response).to receive(:is_a?)
        .with(Net::HTTPSuccess).and_return(false)
      allow(Net::HTTP).to receive(:get_response)
        .and_return(mock_response)
    end

    it "returns invalid_token error" do
      post "/auth/google/one_tap",
           params: { credential: "bad-jwt" },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("invalid_token")
    end
  end

  context "with missing credential" do
    it "returns invalid_token error" do
      post "/auth/google/one_tap", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("invalid_token")
    end
  end

  context "with wrong audience" do
    before do
      stub_google_tokeninfo(
        google_payload.merge("aud" => "wrong-client-id")
      )
    end

    it "returns invalid_token error" do
      post "/auth/google/one_tap",
           params: { credential: "valid-jwt" },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("invalid_token")
    end
  end

  context "when name backfill" do
    it "sets the user name from Google profile when blank" do
      post "/auth/google/one_tap",
           params: { credential: "valid-jwt" },
           as: :json

      expect(user.reload.name).to eq("Jane Doe")
    end

    it "does not overwrite existing name" do
      user.update!(name: "Existing Name")

      post "/auth/google/one_tap",
           params: { credential: "valid-jwt" },
           as: :json

      expect(user.reload.name).to eq("Existing Name")
    end
  end

  private

  def stub_google_tokeninfo(payload)
    mock_response = instance_double(
      Net::HTTPOK, body: payload.to_json
    )
    allow(mock_response).to receive(:is_a?)
      .with(Net::HTTPSuccess).and_return(true)
    allow(Net::HTTP).to receive(:get_response)
      .and_return(mock_response)
  end

  def insert_identity(user, uid)
    sql = ActiveRecord::Base.sanitize_sql_array(
      [
        "INSERT INTO user_omniauth_identities " \
        "(id, user_id, provider, uid) VALUES (?, ?, ?, ?)",
        SecureRandom.uuid, user.id, "google", uid
      ]
    )
    ActiveRecord::Base.connection.execute(sql)
  end

  def identity_count(uid)
    sql = ActiveRecord::Base.sanitize_sql_array(
      [
        "SELECT COUNT(*) FROM user_omniauth_identities " \
        "WHERE provider = 'google' AND uid = ?", uid
      ]
    )
    ActiveRecord::Base.connection.select_value(sql)
  end
end
