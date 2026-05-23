# frozen_string_literal: true

# Operator runbook tasks for the #44 production cutover from :local
# Active Storage to :seaweedfs (SeaweedFS S3). Mirrors the dev-side
# helpers in bin/cli-files/storage-cmd/storage_service.rb so the
# server-side flow is the same shape.
#
# Run inside the app container, in this order:
#   bin/kamal app exec "bin/rails seaweedfs:ensure_bucket"
#   bin/kamal app exec "bin/rails seaweedfs:backfill"
#   bin/kamal app exec "bin/rails seaweedfs:verify"
#   bin/kamal app exec "bin/rails seaweedfs:promote_service_names"
#   bin/kamal app exec "bin/rails seaweedfs:verify_service_names"
# Then push the cutover commit (production.rb → :seaweedfs) + redeploy.
#
# Rollback (only safe while :local still has the bytes):
#   bin/kamal app exec "bin/rails seaweedfs:demote_service_names"

CORS_ALLOWED_ORIGIN = "https://catalyst.workeverywhere.app"

# Helpers for seaweedfs:* tasks. Top-level (not inside the namespace
# block) to satisfy Lint/ConstantDefinitionInBlock, and to keep each
# task body small (Metrics/BlockLength).
module SeaweedfsTasks
  module_function

  def local_service = ActiveStorage::Blob.services.fetch(:local)
  def seaweedfs_service = ActiveStorage::Blob.services.fetch(:seaweedfs)

  def ensure_bucket!
    s3 = seaweedfs_service.client.client
    bucket = seaweedfs_service.bucket.name

    begin
      s3.create_bucket(bucket: bucket)
      puts "bucket created: #{bucket}"
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou,
           Aws::S3::Errors::BucketAlreadyExists
      puts "bucket exists: #{bucket}"
    end

    s3.put_bucket_cors(bucket: bucket, cors_configuration: { cors_rules: [{
                         allowed_origins: [CORS_ALLOWED_ORIGIN], allowed_methods: %w[PUT GET HEAD],
                         allowed_headers: ["*"], expose_headers: ["ETag"], max_age_seconds: 3000
                       }] })
    puts "CORS set: #{CORS_ALLOWED_ORIGIN}"
  end

  def backfill!
    total = ActiveStorage::Blob.count
    counts = { uploaded: 0, skipped: 0, failed: 0 }
    failures = []

    ActiveStorage::Blob.find_each.with_index(1) do |blob, i|
      backfill_one(blob, counts, failures)
      puts "[#{i}/#{total}] #{counts.inspect}" if (i % 25).zero? || i == total
    end

    puts "----"
    puts "total: #{total}  #{counts.inspect}"
    failures.each { |f| puts "  FAILED #{f[:key]}: #{f[:error]}" }
    abort "Backfill had failures — re-run after addressing." if counts[:failed].positive?
  end

  # Returns :uploaded or :skipped. Per-blob rescue: one bad blob never
  # aborts the whole run; counted + logged, the task aborts at the end.
  def backfill_one(blob, counts, failures)
    counts[copy_blob(blob)] += 1
  rescue StandardError => e
    counts[:failed] += 1
    failures << { key: blob.key, error: "#{e.class}: #{e.message}" }
    Rails.logger.error("[seaweedfs:backfill] #{blob.key}: #{e.class}: #{e.message}")
  end

  # Open the on-disk file directly rather than via local.open (which
  # yields a Tempfile through ActiveStorage::Downloader). aws-sdk-s3
  # 1.223 takes a chunked-body code path for Downloader-derived
  # Tempfile IOs that SeaweedFS S3 v3.97 can't validate, producing
  # false BadDigest -> IntegrityError on every non-tiny upload —
  # even after reopening the tempfile's path as a File (which
  # appeared to work in the initial probe but failed under load).
  # Reading straight from the DiskService path stays on the SDK's
  # single-PUT path; validated with 10/10 sequential probes.
  # seaweedfs:verify is the post-hoc integrity gate.
  def copy_blob(blob)
    return :skipped if seaweedfs_service.exist?(blob.key)

    File.open(local_service.send(:path_for, blob.key), "rb") do |io|
      seaweedfs_service.upload(blob.key, io, content_type: blob.content_type)
    end
    :uploaded
  end

  def verify_bytes!
    total = ActiveStorage::Blob.count
    missing = ActiveStorage::Blob.find_each.reject { |b| seaweedfs_service.exist?(b.key) }.map(&:key)
    mismatched = checksum_sample(total, missing)

    puts "blobs: #{total}, missing: #{missing.size}, mismatched: #{mismatched.size}"
    puts "service_name distribution: #{service_name_distribution.inspect}"
    missing.first(20).each { |k| puts "  MISSING #{k}" }
    mismatched.each { |m| puts "  MISMATCH #{m.inspect}" }
    abort "Verify FAILED — DO NOT promote/flip" if missing.any? || mismatched.any?

    puts "OK — bytes verified. Next: rake seaweedfs:promote_service_names"
  end

  # Sample: every video + a random ~5% of the rest. Streams MD5.
  def checksum_sample(total, missing)
    others_size = [(total / 20.0).ceil, 5].max
    videos = ActiveStorage::Blob.where("content_type LIKE 'video/%'").to_a
    others = ActiveStorage::Blob.where.not("content_type LIKE 'video/%'")
                                .order(Arel.sql("RANDOM()")).limit(others_size).to_a
    (videos + others).uniq(&:id).filter_map do |blob|
      next if missing.include?(blob.key)

      got = remote_md5(blob.key)
      next if got == blob.checksum

      { key: blob.key, expected: blob.checksum, got: got }
    rescue StandardError => e
      { key: blob.key, error: "#{e.class}: #{e.message}" }
    end
  end

  def remote_md5(key)
    digest = Digest::MD5.new
    seaweedfs_service.download(key) { |chunk| digest << chunk }
    Base64.strict_encode64(digest.digest)
  end

  def service_name_distribution = ActiveStorage::Blob.group(:service_name).count

  # rubocop:disable Rails/SkipsModelValidations -- bulk service_name rewrite, no model invariants involved
  def rewrite_service_name(from:, to:)
    ActiveStorage::Blob.where(service_name: from).update_all(service_name: to)
  end
  # rubocop:enable Rails/SkipsModelValidations

  def print_rewrite(label:, before:, count:)
    puts "before:  #{before.inspect}"
    puts "#{label}: #{count}"
    puts "after:   #{service_name_distribution.inspect}"
  end

  # Rails' Blob#service consults the persisted service_name first; with
  # ActiveStorageBlobBuilder (app/lib/active_storage_blob_builder.rb)
  # explicitly storing service_name on every row, simply flipping the
  # default service does NOT move reads to :seaweedfs — existing
  # service_name="local" / "mirror" rows still resolve to the old
  # service. This task is the actual read-cutover.
  def verify_service_names!
    by_service = service_name_distribution
    puts "service_name distribution: #{by_service.inspect}"
    stragglers = by_service.except("seaweedfs")
    abort "service_name verify FAILED — #{stragglers.inspect} still on old service" if stragglers.any?

    puts "OK — every blob has service_name='seaweedfs'. Safe to flip production.rb."
  end
end

namespace :seaweedfs do
  desc "Provision the SeaweedFS bucket + CORS policy (idempotent)"
  task ensure_bucket: :environment do
    SeaweedfsTasks.ensure_bucket!
  end

  desc "Backfill existing :local blobs to :seaweedfs (idempotent, resumable)"
  task backfill: :environment do
    SeaweedfsTasks.backfill!
  end

  desc "Verify every blob exists on :seaweedfs; checksum a sample (hard gate before promote)"
  task verify: :environment do
    SeaweedfsTasks.verify_bytes!
  end

  desc "Rewrite blob service_name from local/mirror to seaweedfs (read cutover)"
  task promote_service_names: :environment do
    before = SeaweedfsTasks.service_name_distribution
    count = SeaweedfsTasks.rewrite_service_name(from: %w[local mirror], to: "seaweedfs")
    SeaweedfsTasks.print_rewrite(label: "promoted", before: before, count: count)
  end

  desc "Rollback: rewrite blob service_name from seaweedfs back to local"
  task demote_service_names: :environment do
    before = SeaweedfsTasks.service_name_distribution
    count = SeaweedfsTasks.rewrite_service_name(from: "seaweedfs", to: "local")
    SeaweedfsTasks.print_rewrite(label: "demoted ", before: before, count: count)
  end

  desc "Assert every blob has service_name='seaweedfs' (final gate before flipping production.rb)"
  task verify_service_names: :environment do
    SeaweedfsTasks.verify_service_names!
  end
end
