# frozen_string_literal: true

module Tools
  # Step 1 of the recommended MCP image flow (#172): create a blob
  # row + presigned PUT URL pointing at SeaweedFS. The agent PUTs the
  # bytes directly to that URL (no Rails on the byte path), then
  # calls add_journal_images with the signed_id to attach.
  #
  # Validates content_type, size, and trip writability up front so a
  # failed prepare is cheap.
  class PrepareJournalImageUpload < BaseTool
    description "Step 1 of the recommended Direct Upload flow for " \
                "images. Creates a blob row and returns a presigned " \
                "PUT URL. Agent PUTs bytes to put_url, then calls " \
                "add_journal_images with the returned signed_id. " \
                "Limits: jpeg/png/webp/gif; max 50MB per image."

    ALLOWED_CONTENT_TYPES = %w[
      image/jpeg image/png image/webp image/gif
    ].freeze
    MAX_FILE_SIZE = 50.megabytes
    UPLOAD_EXPIRES_IN = 10.minutes

    input_schema(
      properties: {
        journal_entry_id: {
          type: "string",
          description: "Journal entry UUID — write access is checked up front"
        },
        filename: {
          type: "string",
          description: "Original filename (preserves extension for display)"
        },
        content_type: {
          type: "string",
          description: "MIME type — jpeg/png/webp/gif only"
        },
        byte_size: {
          type: "integer",
          description: "Size in bytes (max 52_428_800 = 50MB)"
        },
        checksum: {
          type: "string",
          description: "Base64-encoded MD5 of the bytes (sent as Content-MD5 on the PUT)"
        }
      },
      required: %w[journal_entry_id filename content_type byte_size checksum]
    )

    # rubocop:disable Metrics/ParameterLists -- 5 user kwargs + _server_context matches the JSON Schema 1:1
    def self.call(journal_entry_id:, filename:, content_type:, byte_size:, checksum:,
                  _server_context: {})
      # rubocop:enable Metrics/ParameterLists
      entry = JournalEntry.find(journal_entry_id)
      require_writable!(entry.trip)
      validate!(content_type, byte_size)

      blob = ActiveStorage::Blob.create_before_direct_upload!(
        filename: filename, content_type: content_type,
        byte_size: byte_size, checksum: checksum
      )

      success_response(direct_upload_payload(blob))
    rescue ToolError => e
      error_response(e.message)
    rescue ActiveRecord::RecordNotFound
      error_response("Journal entry not found: #{journal_entry_id}")
    rescue ActiveRecord::RecordInvalid => e
      error_response(e.record.errors)
    end

    private_class_method def self.validate!(content_type, byte_size)
      unless ALLOWED_CONTENT_TYPES.include?(content_type)
        raise ToolError,
              "Invalid content_type \"#{content_type}\". " \
              "Allowed: #{ALLOWED_CONTENT_TYPES.join(", ")}"
      end

      return if byte_size.to_i <= MAX_FILE_SIZE

      raise ToolError,
            "byte_size #{byte_size} exceeds maximum of #{MAX_FILE_SIZE}"
    end

    private_class_method def self.direct_upload_payload(blob)
      svc = blob.service
      {
        signed_id: blob.signed_id,
        put_url: svc.url_for_direct_upload(
          blob.key, expires_in: UPLOAD_EXPIRES_IN,
                    content_type: blob.content_type,
                    content_length: blob.byte_size, checksum: blob.checksum
        ),
        headers: svc.headers_for_direct_upload(
          blob.key, content_type: blob.content_type,
                    content_length: blob.byte_size, checksum: blob.checksum
        ),
        expires_at: UPLOAD_EXPIRES_IN.from_now.iso8601
      }
    end
  end
end
