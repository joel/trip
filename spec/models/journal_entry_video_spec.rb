# frozen_string_literal: true

require "rails_helper"

RSpec.describe JournalEntryVideo do
  describe "Turbo Stream broadcast on status change (#177)" do
    let(:video) { create(:journal_entry_video, :ready) }

    before { allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to) }

    it "broadcasts a replace targeting the video's dom_id when status changes" do
      # The :ready factory built the row at status: :ready already;
      # transition to :failed so we exercise the after_update_commit.
      video.update!(status: :failed)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
        .with(video.journal_entry, :videos,
              hash_including(target: ActionView::RecordIdentifier.dom_id(video)))
    end

    it "does not broadcast when something other than status changes" do
      video.update!(position: video.position + 1)
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_replace_to)
    end
  end
end
