# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditLog do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:audit_log)).to be_valid
    end

    %i[actor_label action summary event_uid occurred_at].each do |attr|
      it "requires #{attr}" do
        log = build(:audit_log, attr => nil)
        expect(log).not_to be_valid
        expect(log.errors[attr]).to include("can't be blank")
      end
    end

    it "enforces event_uid uniqueness at the database level" do
      create(:audit_log, event_uid: "dup-1")
      dup = build(:audit_log, event_uid: "dup-1")
      expect { dup.save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "associations" do
    it "allows a nil trip (app-wide rows)" do
      expect(build(:audit_log, :app_wide)).to be_valid
    end

    it "allows a nil actor (system rows)" do
      expect(build(:audit_log, :system_source)).to be_valid
    end

    it "belongs to a polymorphic auditable" do
      entry = create(:journal_entry)
      log = create(:audit_log, auditable: entry)
      expect(log.auditable).to eq(entry)
    end
  end

  describe "enums" do
    it "maps source values" do
      expect(described_class.sources)
        .to eq("web" => 0, "mcp" => 1, "telegram" => 2, "system" => 3)
    end
  end

  describe "scopes" do
    it ".recent orders by occurred_at desc, id desc" do
      old = create(:audit_log, occurred_at: 2.days.ago)
      fresh = create(:audit_log, occurred_at: 1.minute.ago)
      expect(described_class.recent.to_a).to eq([fresh, old])
    end

    it ".for_trip filters to a trip" do
      trip = create(:trip)
      mine = create(:audit_log, trip: trip)
      create(:audit_log)
      expect(described_class.for_trip(trip)).to contain_exactly(mine)
    end

    it ".app_wide returns rows with no trip" do
      app = create(:audit_log, :app_wide)
      create(:audit_log)
      expect(described_class.app_wide).to contain_exactly(app)
    end

    it ".high_signal excludes low-signal actions" do
      high = create(:audit_log, action: "journal_entry.created")
      create(:audit_log, :low_signal)
      expect(described_class.high_signal).to contain_exactly(high)
    end
  end

  describe "#low_signal?" do
    it "is true for reaction/checklist-item actions" do
      expect(build(:audit_log, :low_signal).low_signal?).to be(true)
      expect(build(:audit_log, action: "trip.updated").low_signal?)
        .to be(false)
    end
  end

  describe "append-only #readonly?" do
    it "blocks updates once persisted" do
      log = create(:audit_log)
      expect(log.readonly?).to be(true)
      expect { log.update!(summary: "tampered") }
        .to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "blocks destroy once persisted" do
      log = create(:audit_log)
      expect { log.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "still allows the initial create" do
      expect { create(:audit_log) }.to change(described_class, :count).by(1)
    end
  end
end
