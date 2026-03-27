# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notification do
  describe "validations" do
    it "is valid with valid attributes" do
      notification = build(:notification)
      expect(notification).to be_valid
    end

    it "requires event_type" do
      notification = build(:notification, event_type: nil)
      expect(notification).not_to be_valid
      expect(notification.errors[:event_type]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "belongs to notifiable (polymorphic)" do
      entry = create(:journal_entry)
      notification = create(:notification, notifiable: entry)
      expect(notification.notifiable).to eq(entry)
    end

    it "belongs to recipient" do
      user = create(:user)
      notification = create(:notification, recipient: user)
      expect(notification.recipient).to eq(user)
    end

    it "belongs to actor" do
      user = create(:user)
      notification = create(:notification, actor: user)
      expect(notification.actor).to eq(user)
    end
  end

  describe "enums" do
    it "defines event_type enum" do
      expect(described_class.event_types).to eq(
        "member_added" => 0,
        "entry_created" => 1,
        "comment_added" => 2
      )
    end
  end

  describe "scopes" do
    describe ".unread" do
      it "returns only unread notifications" do
        unread = create(:notification)
        create(:notification, :read)

        expect(described_class.unread).to eq([unread])
      end
    end

    describe ".recent" do
      it "orders by created_at descending" do
        old = create(:notification, created_at: 2.days.ago)
        recent = create(:notification, created_at: 1.hour.ago)

        expect(described_class.recent).to eq([recent, old])
      end
    end
  end

  describe "#read?" do
    it "returns false when read_at is nil" do
      notification = build(:notification, read_at: nil)
      expect(notification.read?).to be false
    end

    it "returns true when read_at is present" do
      notification = build(:notification, :read)
      expect(notification.read?).to be true
    end
  end

  describe "#mark_as_read!" do
    it "sets read_at to current time" do
      notification = create(:notification)
      expect(notification.read_at).to be_nil

      freeze_time do
        notification.mark_as_read!
        expect(notification.read_at).to eq(Time.current)
      end
    end
  end

  describe "uniqueness" do
    it "prevents duplicate notifications" do
      entry = create(:journal_entry)
      user = create(:user)
      actor = create(:user)

      create(:notification,
             notifiable: entry,
             recipient: user,
             actor: actor,
             event_type: :entry_created)

      duplicate = build(:notification,
                        notifiable: entry,
                        recipient: user,
                        actor: actor,
                        event_type: :entry_created)

      expect { duplicate.save! }.to raise_error(
        ActiveRecord::RecordNotUnique
      )
    end
  end
end
