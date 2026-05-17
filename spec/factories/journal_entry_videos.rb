# frozen_string_literal: true

FactoryBot.define do
  factory :journal_entry_video do
    journal_entry
    status { :pending }
    sequence(:position) { |n| n }

    after(:build) do |video|
      video.source.attach(
        io: Rails.root.join("spec/fixtures/files/tiny.mp4").open,
        filename: "tiny.mp4", content_type: "video/mp4"
      )
    end

    trait :ready do
      status { :ready }
      duration { 1.0 }
      width { 160 }
      height { 120 }

      after(:build) do |video|
        video.web.attach(
          io: Rails.root.join("spec/fixtures/files/tiny.mp4").open,
          filename: "tiny-web.mp4", content_type: "video/mp4"
        )
        video.poster.attach(
          io: Rails.root.join("spec/fixtures/files/pixel.png").open,
          filename: "poster.png", content_type: "image/png"
        )
      end
    end
  end
end
