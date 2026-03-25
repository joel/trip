# frozen_string_literal: true

module JournalEntries
  class UploadImages < BaseAction
    ALLOWED_CONTENT_TYPES = %w[
      image/jpeg image/png image/webp image/gif
    ].freeze
    MAX_IMAGES_PER_CALL = 5
    MAX_IMAGES_PER_ENTRY = 20
    MAX_FILE_SIZE = 10.megabytes
    MAX_ENCODED_SIZE = (MAX_FILE_SIZE * 4 / 3) + 4

    MIME_TO_EXT = {
      "image/jpeg" => "jpg",
      "image/png" => "png",
      "image/webp" => "webp",
      "image/gif" => "gif"
    }.freeze

    def call(journal_entry:, images:)
      images = normalize_images(images)
      yield validate_images(images)
      yield validate_image_count(journal_entry, images)
      staged = yield decode_all(images)
      yield attach_all(journal_entry, staged)
      yield emit_event(journal_entry, staged.size)
      Success(journal_entry)
    end

    private

    def normalize_images(images)
      return images unless images.is_a?(Array)

      images.map do |img|
        img.is_a?(Hash) ? img.transform_keys(&:to_sym) : img
      end
    end

    def validate_images(images)
      return Failure("images must be a non-empty array") if images.blank? || !images.is_a?(Array)

      if images.size > MAX_IMAGES_PER_CALL
        return Failure(
          "Too many images (#{images.size}). " \
          "Maximum is #{MAX_IMAGES_PER_CALL} per call"
        )
      end

      Success()
    end

    def validate_image_count(journal_entry, images)
      current = journal_entry.images.count
      if current + images.size > MAX_IMAGES_PER_ENTRY
        return Failure(
          "Would exceed maximum of " \
          "#{MAX_IMAGES_PER_ENTRY} images " \
          "(current: #{current}, adding: #{images.size})"
        )
      end

      Success()
    end

    def decode_all(images)
      staged = images.each_with_index.map do |img, idx|
        decode_one(img, idx)
      end
      Success(staged)
    rescue DecodeError => e
      Failure(e.message)
    end

    def decode_one(img, index)
      data = img[:data]
      raise DecodeError, "Missing data for image #{index}" if data.blank?

      if data.bytesize > MAX_ENCODED_SIZE
        raise DecodeError,
              "Image #{index} data too large " \
              "(encoded size exceeds limit)"
      end

      bytes = Base64.strict_decode64(data)
      content_type = validate_decoded!(bytes, index)
      filename = img[:filename].presence ||
                 "image_#{index}.#{MIME_TO_EXT[content_type]}"

      {
        io: StringIO.new(bytes),
        filename: filename,
        content_type: content_type
      }
    rescue ArgumentError => e
      raise DecodeError,
            "Invalid base64 data for image #{index}: " \
            "#{e.message}"
    end

    def validate_decoded!(bytes, index)
      content_type = Marcel::MimeType.for(StringIO.new(bytes))
      unless ALLOWED_CONTENT_TYPES.include?(content_type)
        raise DecodeError,
              "Invalid content type \"#{content_type}\" " \
              "for image #{index}. " \
              "Allowed: #{ALLOWED_CONTENT_TYPES.join(", ")}"
      end

      if bytes.bytesize > MAX_FILE_SIZE
        raise DecodeError,
              "Image #{index} too large " \
              "(#{bytes.bytesize} bytes). " \
              "Maximum is #{MAX_FILE_SIZE} bytes"
      end

      content_type
    end

    def attach_all(journal_entry, staged)
      ActiveRecord::Base.transaction do
        staged.each do |attachment|
          journal_entry.images.attach(attachment)
        end
      end
      Success()
    end

    def emit_event(journal_entry, count)
      Rails.event.notify(
        "journal_entry.images_added",
        journal_entry_id: journal_entry.id,
        trip_id: journal_entry.trip_id,
        count: count
      )
      Success()
    end

    class DecodeError < StandardError; end
  end
end
