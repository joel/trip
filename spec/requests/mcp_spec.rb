# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MCP Endpoint" do
  let(:api_key) { "test-mcp-api-key" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("MCP_API_KEY", nil).and_return(api_key)
  end

  describe "POST /mcp" do
    let(:headers) do
      {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json"
      }
    end

    let(:init_payload) do
      {
        jsonrpc: "2.0", id: "1",
        method: "initialize",
        params: {
          protocolVersion: "2025-03-26",
          capabilities: {},
          clientInfo: { name: "test", version: "1.0" }
        }
      }.to_json
    end

    context "without API key" do
      it "returns 401 unauthorized" do
        post "/mcp", params: "{}", headers: { "Content-Type" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with wrong API key" do
      it "returns 401 unauthorized" do
        post "/mcp", params: "{}", headers: {
          "Authorization" => "Bearer wrong-key",
          "Content-Type" => "application/json"
        }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with blank MCP_API_KEY env var" do
      before do
        allow(ENV).to receive(:fetch).with("MCP_API_KEY", nil).and_return("")
      end

      it "returns 401 unauthorized" do
        post "/mcp", params: "{}", headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with invalid Content-Type" do
      it "returns 415 Unsupported Media Type" do
        post "/mcp", params: "{}", headers: {
          "Authorization" => "Bearer #{api_key}",
          "Content-Type" => "text/plain"
        }
        expect(response).to have_http_status(:unsupported_media_type)
      end
    end

    context "with malformed JSON" do
      it "returns JSON-RPC parse error" do
        post "/mcp", params: "not json{{{", headers: headers
        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body["error"]["code"]).to eq(-32_700)
        expect(body["error"]["message"]).to eq("Parse error")
      end
    end

    context "with valid API key" do
      it "responds to initialize request" do
        post "/mcp", params: init_payload, headers: headers
        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body["result"]["serverInfo"]["name"])
          .to eq("trip_journal")
      end

      it "lists all 10 tools" do
        post "/mcp", params: init_payload, headers: headers

        list_payload = {
          jsonrpc: "2.0", id: "2", method: "tools/list"
        }.to_json
        post "/mcp", params: list_payload, headers: headers
        expect(response).to have_http_status(:ok)

        tool_names = response.parsed_body["result"]["tools"]
                             .pluck("name")
        expect(tool_names).to contain_exactly(
          "create_journal_entry", "update_journal_entry",
          "list_journal_entries", "create_comment",
          "add_reaction", "update_trip", "transition_trip",
          "toggle_checklist_item", "list_checklists",
          "get_trip_status"
        )
      end

      it "executes tools/call and creates a journal entry" do # rubocop:disable RSpec/ExampleLength
        trip = create(:trip, :started)
        post "/mcp", params: init_payload, headers: headers

        call_payload = {
          jsonrpc: "2.0", id: "3",
          method: "tools/call",
          params: {
            name: "create_journal_entry",
            arguments: {
              trip_id: trip.id,
              name: "MCP Test Entry",
              entry_date: Date.current.to_s
            }
          }
        }.to_json

        expect do
          post "/mcp", params: call_payload, headers: headers
        end.to change(JournalEntry, :count).by(1)

        expect(response).to have_http_status(:ok)
        content = response.parsed_body["result"]["content"]
        data = JSON.parse(content.first["text"])
        expect(data["name"]).to eq("MCP Test Entry")
        expect(data["trip_id"]).to eq(trip.id)
      end
    end
  end
end
