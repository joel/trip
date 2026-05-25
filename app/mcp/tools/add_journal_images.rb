# frozen_string_literal: true

module Tools
  class AddJournalImages < BaseTool
    description "Attach images to a journal entry. Recommended flow " \
                "(#172): call prepare_journal_image_upload first, " \
                "PUT bytes to the returned put_url, then call this " \
                "with signed_ids. Fallback: pass HTTPS urls and the " \
                "server downloads (SSRF-hardened). Pass exactly one " \
                "of signed_ids or urls. " \
                "Limits: jpeg/png/webp/gif. Max 5 urls or signed_ids " \
                "per call; max 20 images per entry."

    input_schema(
      properties: {
        journal_entry_id: {
          type: "string",
          description: "Journal entry UUID"
        },
        urls: {
          type: "array",
          items: { type: "string" },
          description: "Image URLs (HTTPS, max 5). Mutually exclusive with signed_ids."
        },
        signed_ids: {
          type: "array",
          items: { type: "string" },
          description: "Active Storage signed_ids from " \
                       "prepare_journal_image_upload (recommended). " \
                       "Mutually exclusive with urls."
        }
      },
      required: %w[journal_entry_id]
    )

    def self.call(journal_entry_id:, urls: nil, signed_ids: nil, _server_context: {})
      entry = JournalEntry.find(journal_entry_id)
      require_writable!(entry.trip)
      result = dispatch(entry, urls, signed_ids)

      case result
      in Dry::Monads::Success(updated)
        success_response(
          journal_entry_id: updated.id,
          attached: (signed_ids.presence || urls).to_a.size,
          total_images: updated.images.count
        )
      in Dry::Monads::Failure(errors)
        error_response(errors)
      end
    rescue ToolError => e
      error_response(e.message)
    rescue ActiveRecord::RecordNotFound
      error_response("Journal entry not found: #{journal_entry_id}")
    end

    private_class_method def self.dispatch(entry, urls, signed_ids)
      urls_given = urls.is_a?(Array) && urls.any?
      sids_given = signed_ids.is_a?(Array) && signed_ids.any?
      raise ToolError, "Provide exactly one of urls or signed_ids, not both" if urls_given && sids_given

      if sids_given
        JournalEntries::AttachUploadedImages.new.call(
          journal_entry: entry, signed_ids: signed_ids
        )
      elsif urls_given
        JournalEntries::AttachImages.new.call(
          journal_entry: entry, urls: urls
        )
      else
        raise ToolError, "Provide either urls or signed_ids"
      end
    end
  end
end
