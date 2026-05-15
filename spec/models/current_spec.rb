# frozen_string_literal: true

require "rails_helper"

RSpec.describe Current do
  after { described_class.reset }

  it "holds actor, request_id and source" do
    user = build(:user)
    described_class.actor = user
    described_class.request_id = "req-1"
    described_class.source = :mcp

    expect(described_class.actor).to eq(user)
    expect(described_class.request_id).to eq("req-1")
    expect(described_class.source).to eq(:mcp)
  end

  it "resets between units of work" do
    described_class.actor = build(:user)
    described_class.reset
    expect(described_class.actor).to be_nil
  end

  describe "controller wiring" do
    it "registers set_audit_context as an ApplicationController before_action" do
      filters = ApplicationController._process_action_callbacks
                                     .select { |c| c.kind == :before }
                                     .map(&:filter)
      expect(filters).to include(:set_audit_context)
    end
  end
end
