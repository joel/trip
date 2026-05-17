# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MCP Endpoint" do
  let(:api_key) { "test-mcp-api-key" }
  let!(:agent) { create(:agent, slug: "jack", name: "Jack") }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("MCP_API_KEY", nil).and_return(api_key)
  end

  describe "POST /mcp" do
    let(:headers) do
      {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json",
        "X-Agent-Identifier" => agent.slug
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

    context "without X-Agent-Identifier header" do
      it "returns JSON-RPC error -32001 with a helpful message" do
        post "/mcp", params: init_payload,
                     headers: headers.except("X-Agent-Identifier")
        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body["error"]["code"]).to eq(-32_001)
        expect(body["error"]["message"])
          .to include("X-Agent-Identifier")
      end
    end

    context "with unknown agent slug" do
      it "returns JSON-RPC error -32001 with the slug echoed back" do
        post "/mcp", params: init_payload,
                     headers: headers.merge("X-Agent-Identifier" => "ghost")
        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body["error"]["code"]).to eq(-32_001)
        expect(body["error"]["message"]).to include("'ghost'")
      end
    end

    context "with valid API key and agent" do
      it "responds to initialize request" do
        post "/mcp", params: init_payload, headers: headers
        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body["result"]["serverInfo"]["name"])
          .to eq("trip_journal")
      end

      it "personalises instructions with the resolved agent name" do
        post "/mcp", params: init_payload, headers: headers

        instructions = response.parsed_body["result"]["instructions"]
        expect(instructions).to include("You are Jack")
      end

      it "lists exactly the registered tools" do
        post "/mcp", params: init_payload, headers: headers

        list_payload = {
          jsonrpc: "2.0", id: "2", method: "tools/list"
        }.to_json
        post "/mcp", params: list_payload, headers: headers
        expect(response).to have_http_status(:ok)

        tool_names = response.parsed_body["result"]["tools"]
                             .pluck("name")
        expect(tool_names)
          .to match_array(TripJournalServer::TOOLS.map(&:name_value))
        expect(tool_names).to include(
          "get_journal_entry", "delete_journal_entry",
          "update_comment", "delete_comment", "list_comments",
          "list_reactions", "list_trips", "create_checklist",
          "update_checklist", "delete_checklist",
          "create_checklist_item",
          "add_journal_videos", "upload_journal_videos"
        )
      end

      it "executes tools/call and creates a journal entry " \
         "attributed to the agent" do
        trip = create(:trip, :started)
        post "/mcp", params: init_payload, headers: headers

        expect { post("/mcp", params: create_entry_call(trip), headers: headers) }
          .to change(JournalEntry, :count).by(1)

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.parsed_body["result"]["content"].first["text"])
        expect(data["name"]).to eq("MCP Test Entry")
        expect(JournalEntry.find(data["id"]).author).to eq(agent.user)
      end

      def create_entry_call(trip)
        {
          jsonrpc: "2.0", id: "3", method: "tools/call",
          params: {
            name: "create_journal_entry",
            arguments: {
              trip_id: trip.id, name: "MCP Test Entry",
              entry_date: Date.current.to_s
            }
          }
        }.to_json
      end
    end
  end
end
