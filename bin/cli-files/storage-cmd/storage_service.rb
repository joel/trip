#!/usr/bin/env ruby

require_relative "../services/helpers"

module AppCLI
  module Services
    # Local SeaweedFS object store (S3-compatible) backing Active
    # Storage in dev. Mirrors MailService: a detached container on the
    # shared Traefik network, reachable by the browser (direct upload)
    # and the app container at https://storage.workeverywhere.docker.
    # Persistence via a named volume so blobs survive restarts.
    class StorageService
      STORAGE_CONTAINER = "seaweedfs".freeze
      STORAGE_IMAGE = "chrislusf/seaweedfs:3.97".freeze
      STORAGE_PORT = "8333".freeze
      STORAGE_HOST = "storage.workeverywhere.docker".freeze
      STORAGE_ROUTER = "catalyst-seaweedfs".freeze
      STORAGE_VOLUME = "catalyst-seaweedfs-data".freeze
      STORAGE_BUCKET = "catalyst".freeze

      def initialize(shell:)
        @runner = CommandRunner.new(shell: shell)
        @shell = shell
      end

      def start
        runner.ensure_network(Services::NETWORK_NAME)
        runner.ensure_volume(STORAGE_VOLUME)

        status = runner.container_status(STORAGE_CONTAINER)
        if status == "running"
          shell.say("Storage service already running.")
          ensure_bucket
          return
        end

        if status != "missing"
          shell.say("Removing existing storage container (status: #{status}).")
          runner.run("docker rm #{STORAGE_CONTAINER}", allow_failure: true)
        end

        runner.run(storage_run_command)
        ensure_bucket
      end

      def stop
        if runner.container_running?(STORAGE_CONTAINER)
          shell.say("Stopping storage service container")
          runner.run("docker stop #{STORAGE_CONTAINER}")
        else
          shell.say("Storage service not running, skipping stop.")
        end
      end

      def logs(follow: true)
        args = follow ? "-f" : ""
        runner.run("docker logs #{args} #{STORAGE_CONTAINER}")
      end

      def status
        runner.container_status(STORAGE_CONTAINER)
      end

      # SeaweedFS does not auto-create S3 buckets. CreateBucket is a
      # plain `PUT /<bucket>` on the S3 endpoint (anonymous is allowed
      # — no -s3.config), and is idempotent (200 whether or not it
      # already exists). Done over the published host port so it needs
      # no extra tooling in the container.
      def ensure_bucket
        runner.run(
          "curl -s -o /dev/null -X PUT " \
          "http://localhost:#{STORAGE_PORT}/#{STORAGE_BUCKET}",
          allow_failure: true
        )
      end

      private

      attr_reader :runner, :shell

      def storage_run_command
        [
          "docker run --rm --detach",
          "--name #{STORAGE_CONTAINER}",
          "--publish #{STORAGE_PORT}:8333",
          "--network #{Services::NETWORK_NAME}",
          "--volume #{STORAGE_VOLUME}:/data",
          "--label traefik.enable=true",
          "--label 'traefik.http.routers.#{STORAGE_ROUTER}.rule=" \
          "Host(`#{STORAGE_HOST}`)'",
          "--label traefik.http.routers.#{STORAGE_ROUTER}.entrypoints=websecure",
          "--label traefik.http.routers.#{STORAGE_ROUTER}.tls=true",
          "--label traefik.http.services.#{STORAGE_ROUTER}." \
          "loadbalancer.server.port=8333",
          "--label traefik.docker.network=#{Services::NETWORK_NAME}",
          STORAGE_IMAGE,
          "server -s3 -dir=/data -ip.bind=0.0.0.0"
        ]
      end
    end
  end
end
