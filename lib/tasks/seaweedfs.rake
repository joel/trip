# frozen_string_literal: true

# Operator runbook tasks for the #44 production cutover from :local
# Active Storage to :seaweedfs (SeaweedFS S3). Mirror the dev-side
# helpers in bin/cli-files/storage-cmd/storage_service.rb so the
# server-side flow is the same shape.
#
# Run inside the app container:
#   bin/kamal app exec "bin/rails seaweedfs:ensure_bucket"
#   bin/kamal app exec "bin/rails seaweedfs:backfill"
#   bin/kamal app exec "bin/rails seaweedfs:verify"

CORS_ALLOWED_ORIGIN = "https://catalyst.workeverywhere.app"

# Helpers for seaweedfs:* tasks. Top-level (not inside the namespace
# block) to satisfy Lint/ConstantDefinitionInBlock.
module SeaweedfsTasks
  module_function

  def local_service = ActiveStorage::Blob.services.fetch(:local)
  def seaweedfs_service = ActiveStorage::Blob.services.fetch(:seaweedfs)

  # Returns :uploaded or :skipped. Raises on real errors so the caller
  # can count + log per-blob without aborting the whole run.
  def copy_blob(blob)
    return :skipped if seaweedfs_service.exist?(blob.key)

    local_service.open(blob.key) do |io|
      seaweedfs_service.upload(blob.key, io,
                               checksum: blob.checksum,
                               content_type: blob.content_type)
    end
    :uploaded
  end

  # Stream the remote blob through MD5 (Active Storage's checksum is
  # base64(md5)); avoids loading the whole file into memory.
  def remote_md5(key)
    digest = Digest::MD5.new
    seaweedfs_service.download(key) { |chunk| digest << chunk }
    Base64.strict_encode64(digest.digest)
  end
end

namespace :seaweedfs do
  desc "Provision the SeaweedFS bucket + CORS policy (idempotent)"
  task ensure_bucket: :environment do
    svc = ActiveStorage::Blob.services.fetch(:seaweedfs)
    s3 = svc.client.client
    bucket = svc.bucket.name

    begin
      s3.create_bucket(bucket: bucket)
      puts "bucket created: #{bucket}"
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou,
           Aws::S3::Errors::BucketAlreadyExists
      puts "bucket exists: #{bucket}"
    end

    s3.put_bucket_cors(
      bucket: bucket,
      cors_configuration: {
        cors_rules: [{
          allowed_origins: [CORS_ALLOWED_ORIGIN],
          allowed_methods: %w[PUT GET HEAD],
          allowed_headers: ["*"],
          expose_headers: ["ETag"],
          max_age_seconds: 3000
        }]
      }
    )
    puts "CORS set: #{CORS_ALLOWED_ORIGIN}"
  end

  desc "Backfill existing :local blobs to :seaweedfs (idempotent, resumable)"
  task backfill: :environment do
    total = ActiveStorage::Blob.count
    counts = { uploaded: 0, skipped: 0, failed: 0 }
    failures = []

    ActiveStorage::Blob.find_each.with_index(1) do |blob, i|
      begin
        result = SeaweedfsTasks.copy_blob(blob)
        counts[result] += 1
      rescue StandardError => e
        counts[:failed] += 1
        failures << { key: blob.key, error: "#{e.class}: #{e.message}" }
        Rails.logger.error("[seaweedfs:backfill] #{blob.key}: #{e.class}: #{e.message}")
      end
      puts "[#{i}/#{total}] #{counts.inspect}" if (i % 25).zero? || i == total
    end

    puts "----"
    puts "total: #{total}  #{counts.inspect}"
    failures.each { |f| puts "  FAILED #{f[:key]}: #{f[:error]}" }
    abort "Backfill had failures — re-run after addressing." if counts[:failed].positive?
  end

  desc "Verify every blob exists on :seaweedfs; checksum a sample (hard gate before cutover)"
  task verify: :environment do
    total = ActiveStorage::Blob.count
    missing = ActiveStorage::Blob.find_each.reject { |b| SeaweedfsTasks.seaweedfs_service.exist?(b.key) }.map(&:key)

    # Sample: every video + a random ~5% of the rest (min 5).
    videos = ActiveStorage::Blob.where("content_type LIKE 'video/%'")
    others_sample_size = [(total / 20.0).ceil, 5].max
    others = ActiveStorage::Blob.where.not("content_type LIKE 'video/%'")
                                .order(Arel.sql("RANDOM()")).limit(others_sample_size)
    mismatched = []

    (videos.to_a + others.to_a).uniq(&:id).each do |blob|
      next if missing.include?(blob.key)

      got = SeaweedfsTasks.remote_md5(blob.key)
      next if got == blob.checksum

      mismatched << { key: blob.key, expected: blob.checksum, got: got }
    rescue StandardError => e
      mismatched << { key: blob.key, error: "#{e.class}: #{e.message}" }
    end

    puts "blobs: #{total}, missing: #{missing.size}, mismatched: #{mismatched.size}"
    missing.first(20).each { |k| puts "  MISSING #{k}" }
    mismatched.each { |m| puts "  MISMATCH #{m.inspect}" }
    abort "Verify FAILED — DO NOT flip to :seaweedfs" if missing.any? || mismatched.any?

    puts "OK — safe to flip production to :seaweedfs"
  end
end
