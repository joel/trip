# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationMailer do
  let(:admin) { create(:user, :superadmin, name: "Alice") }
  let(:trip) { create(:trip, name: "Japan Trip", created_by: admin) }
  let(:member) { create(:user, name: "Bob") }

  before do
    create(:trip_membership, trip: trip, user: member)
    create(:trip_membership, trip: trip, user: admin)
  end

  describe "#entry_created" do
    let(:entry) do
      create(:journal_entry, :with_body, :with_location,
             trip: trip, author: admin, name: "Day in Tokyo",
             description: "A wonderful day exploring the city")
    end
    let(:mail) { described_class.entry_created(entry.id, member.id) }

    it "sends to the recipient" do
      expect(mail.to).to eq([member.email])
    end

    it "sets the subject with trip and entry names" do
      expect(mail.subject).to eq(
        "New entry in Japan Trip: Day in Tokyo"
      )
    end

    it "includes entry title in HTML part" do
      html = mail.html_part.body.to_s
      expect(html).to include("Day in Tokyo")
    end

    it "includes Read Online link in HTML part" do
      html = mail.html_part.body.to_s
      expect(html).to include("Read Online")
    end

    it "includes body content in HTML part" do
      html = mail.html_part.body.to_s
      expect(html).to include("bold text")
    end

    it "includes description in HTML part" do
      html = mail.html_part.body.to_s
      expect(html).to include("A wonderful day exploring the city")
    end

    it "includes location in HTML part" do
      html = mail.html_part.body.to_s
      expect(html).to include("Paris, France")
    end

    it "includes entry title in text part" do
      text = mail.text_part.body.to_s
      expect(text).to include("Day in Tokyo")
    end

    it "includes Read Online link in text part" do
      text = mail.text_part.body.to_s
      expect(text).to include("Read Online")
    end

    it "includes body content in text part" do
      text = mail.text_part.body.to_s
      expect(text).to include("bold text")
    end

    context "when entry has no body" do
      let(:entry) do
        create(:journal_entry,
               trip: trip, author: admin, name: "Quick Note")
      end

      it "renders without errors" do
        expect(mail.html_part.body.to_s).to include("Quick Note")
        expect(mail.text_part.body.to_s).to include("Quick Note")
      end
    end

    context "when entry has no description" do
      let(:entry) do
        create(:journal_entry, :with_body,
               trip: trip, author: admin, name: "No Desc")
      end

      it "renders without errors" do
        expect(mail.html_part.body.to_s).to include("No Desc")
        expect(mail.text_part.body.to_s).to include("No Desc")
      end
    end

    context "when entry has images" do
      let(:entry) do
        create(:journal_entry, :with_body, :with_images,
               trip: trip, author: admin, name: "Photo Entry")
      end

      it "includes inline attachments" do
        expect(mail.attachments.count).to eq(1)
        expect(mail.attachments.first.filename)
          .to eq("0_test_photo.png")
      end

      it "references image in HTML part" do
        html = mail.html_part.body.to_s
        expect(html).to include("cid:")
      end

      it "notes image count in text part" do
        text = mail.text_part.body.to_s
        expect(text).to include("[1 image attached]")
      end
    end

    it "returns nil mail when entry not found" do
      result = described_class.entry_created("nonexistent", member.id)
      expect(result.message).to be_a(ActionMailer::Base::NullMail)
    end

    it "returns nil mail when recipient not found" do
      result = described_class.entry_created(entry.id, "nonexistent")
      expect(result.message).to be_a(ActionMailer::Base::NullMail)
    end
  end

  describe "#comment_added" do
    let(:entry) do
      create(:journal_entry,
             trip: trip, author: admin, name: "Test Entry")
    end
    let(:comment) do
      create(:comment,
             journal_entry: entry, user: member, body: "Great post!")
    end
    let(:mail) do
      described_class.comment_added(comment.id, admin.id)
    end

    it "sends to the recipient" do
      expect(mail.to).to eq([admin.email])
    end

    it "sets the subject" do
      expect(mail.subject).to eq(
        "New comment on Test Entry in Japan Trip"
      )
    end
  end
end
