# frozen_string_literal: true

module JournalEntries
  # Signed-id path for images, mirroring AttachUploadedVideos. The
  # caller (web form post-Direct-Upload, or MCP after
  # prepare_journal_image_upload) submits signed_ids of blobs already
  # PUT to SeaweedFS. We resolve, validate, then attach as
  # has_many_attached :images. Content type and byte_size are
  # validated server-side from the blob's recorded metadata so an
  # agent can't smuggle in oversized or unsupported media.
  class AttachUploadedImages < BaseAction
    ALLOWED_CONTENT_TYPES = %w[
      image/jpeg image/png image/webp image/gif
    ].freeze
    MAX_IMAGES_PER_ENTRY = 20
    MAX_FILE_SIZE = 50.megabytes

    def call(journal_entry:, signed_ids:)
      blobs = yield resolve_blobs(signed_ids)
      yield validate(journal_entry, blobs)
      yield attach_all(journal_entry, blobs)
      yield emit_event(journal_entry, blobs.size)
      Success(journal_entry)
    end

    private

    def resolve_blobs(signed_ids)
      blobs = Array(signed_ids).compact_blank.map do |sid|
        ActiveStorage::Blob.find_signed!(sid)
      end
      Success(blobs)
    rescue ActiveSupport::MessageVerifier::InvalidSignature,
           ActiveRecord::RecordNotFound
      Failure("One or more uploaded images could not be found")
    end

    def validate(journal_entry, blobs)
      return Failure("signed_ids must be a non-empty array") if blobs.empty?

      current = journal_entry.images.count
      if current + blobs.size > MAX_IMAGES_PER_ENTRY
        return Failure(
          "Would exceed maximum of #{MAX_IMAGES_PER_ENTRY} images " \
          "(current: #{current}, adding: #{blobs.size})"
        )
      end

      blobs.each do |blob|
        unless ALLOWED_CONTENT_TYPES.include?(blob.content_type)
          return Failure(
            "Invalid image type \"#{blob.content_type}\". " \
            "Allowed: #{ALLOWED_CONTENT_TYPES.join(", ")}"
          )
        end
        if blob.byte_size > MAX_FILE_SIZE
          return Failure(
            "Image too large (#{blob.byte_size} bytes). " \
            "Maximum is #{MAX_FILE_SIZE} bytes"
          )
        end
      end

      Success()
    end

    def attach_all(journal_entry, blobs)
      blobs.each { |blob| journal_entry.images.attach(blob) }
      Success()
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
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
  end
end
