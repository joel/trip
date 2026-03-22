# frozen_string_literal: true

require "rails_helper"

RSpec.describe Comments::Create do
  let(:admin) { create(:user, :superadmin) }
  let(:trip) { create(:trip, created_by: admin) }
  let(:entry) { create(:journal_entry, trip: trip, author: admin) }

  describe "#call" do
    it "creates a comment with valid params" do
      result = described_class.new.call(
        params: { body: "Nice entry!" },
        journal_entry: entry,
        user: admin
      )

      expect(result).to be_success
      comment = result.value!
      expect(comment.body).to eq("Nice entry!")
      expect(comment.journal_entry).to eq(entry)
      expect(comment.user).to eq(admin)
    end

    it "returns failure with blank body" do
      result = described_class.new.call(
        params: { body: "" },
        journal_entry: entry,
        user: admin
      )

      expect(result).to be_failure
    end
  end
end
