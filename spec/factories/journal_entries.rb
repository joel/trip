# frozen_string_literal: true

FactoryBot.define do
  factory :journal_entry do
    trip
    author factory: %i[user]
    name { "Day 1" }
    entry_date { Date.current }

    trait :with_location do
      location_name { "Paris, France" }
      latitude { 48.8566 }
      longitude { 2.3522 }
    end

    trait :with_body do
      body { "Sample journal entry content with <strong>bold text</strong>." }
    end

    trait :with_images do
      after(:create) do |entry|
        # 1x1 red PNG (67 bytes)
        png = "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00" \
              "\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS" \
              "\xDE\x00\x00\x00\x0CIDAT\x08\xD7c\xF8\xCF\xC0" \
              "\x00\x00\x00\x03\x00\x01\x00\x05\xFE\xD4\x00" \
              "\x00\x00\x00IEND\xAEB`\x82"
        io = StringIO.new(png.dup.force_encoding("BINARY"))
        blob = ActiveStorage::Blob.new(
          id: SecureRandom.uuid,
          key: SecureRandom.base36(28),
          filename: "test_photo.png",
          content_type: "image/png",
          service_name: ActiveStorage::Blob.service.name
        )
        blob.upload(io)
        blob.save!
        entry.images.attach(blob)
      end
    end
  end
end
