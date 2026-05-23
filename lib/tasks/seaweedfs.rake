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
end
