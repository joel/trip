# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reactions::Toggle do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:entry) { create(:journal_entry, trip: trip, author: admin) }

  describe "#call" do
    it "creates a reaction when none exists" do
      result = described_class.new.call(
        reactable: entry, user: admin, emoji: "thumbsup"
      )

      expect(result).to be_success
      expect(entry.reactions.count).to eq(1)
    end

    it "removes a reaction when one already exists" do
      create(:reaction, reactable: entry, user: admin,
                        emoji: "thumbsup")

      result = described_class.new.call(
        reactable: entry, user: admin, emoji: "thumbsup"
      )

      expect(result).to be_success
      expect(result.value!).to eq(:removed)
      expect(entry.reactions.count).to eq(0)
    end
  end
end
