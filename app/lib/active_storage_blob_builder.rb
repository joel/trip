# frozen_string_literal: true

# Builds + persists an ActiveStorage::Blob with an explicit UUID id.
# `attach(io:)` goes through ActiveStorage::Blob.create_and_upload!,
# which does not set a primary key — and this app's active_storage_*
# tables use UUID ids with no DB default, so the insert fails
# (NOT NULL on active_storage_blobs.id). Mirrors the in-repo
# precedent in the :with_images factory. Use this whenever attaching
# from an IO, then `record.attachment.attach(blob)`.
module ActiveStorageBlobBuilder
  module_function

  def upload(io:, filename:, content_type:)
    blob = ActiveStorage::Blob.new(
      id: SecureRandom.uuid,
      key: SecureRandom.base36(28),
      filename: filename,
      content_type: content_type,
      service_name: ActiveStorage::Blob.service.name
    )
    blob.upload(io)
    blob.save!
    blob
  end
end
