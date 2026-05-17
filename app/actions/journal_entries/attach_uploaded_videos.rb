# frozen_string_literal: true

module JournalEntries
  # Web-form path (Q4): the browser direct-uploads video bytes straight
  # to storage (23a) and submits the resulting signed blob ids. Each
  # becomes a JournalEntryVideo(:pending); ProcessJournalVideosJob then
  # transcodes. Content type + size are validated synchronously here;
  # duration is enforced by the job (probing 200MB in the request would
  # mean downloading it back — the agent URL path gates duration up
  # front, the form path defers it).
  class AttachUploadedVideos < BaseAction
    ALLOWED_CONTENT_TYPES = %w[
      video/mp4 video/quicktime video/webm
    ].freeze
    MAX_VIDEOS_PER_ENTRY = 5
    MAX_FILE_SIZE = 200.megabytes

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
      Failure("One or more uploaded videos could not be found")
    end

    def validate(journal_entry, blobs)
      current = journal_entry.videos.count
      if current + blobs.size > MAX_VIDEOS_PER_ENTRY
        return Failure(
          "Would exceed maximum of #{MAX_VIDEOS_PER_ENTRY} videos"
        )
      end

      blobs.each do |blob|
        unless ALLOWED_CONTENT_TYPES.include?(blob.content_type)
          return Failure(
            "Invalid video type \"#{blob.content_type}\". " \
            "Allowed: #{ALLOWED_CONTENT_TYPES.join(", ")}"
          )
        end
        if blob.byte_size > MAX_FILE_SIZE
          return Failure(
            "Video too large (#{blob.byte_size} bytes). " \
            "Maximum is #{MAX_FILE_SIZE} bytes"
          )
        end
      end

      Success()
    end

    def attach_all(journal_entry, blobs)
      ActiveRecord::Base.transaction do
        base = journal_entry.videos.maximum(:position).to_i
        blobs.each_with_index do |blob, i|
          video = journal_entry.videos.create!(
            status: :pending, position: base + i + 1
          )
          video.source.attach(blob)
        end
      end
      Success()
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(journal_entry, count)
      Rails.event.notify(
        "journal_entry.videos_added",
        journal_entry_id: journal_entry.id,
        trip_id: journal_entry.trip_id,
        count: count
      )
      Success()
    end
  end
end
