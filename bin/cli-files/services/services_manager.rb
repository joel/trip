#!/usr/bin/env ruby

require_relative "helpers"
require_relative "../app-cmd/app_service"
require_relative "../db-cmd/db_service"

module AppCLI
  module Services
    class ServicesManager
      attr_reader :app, :db

      def initialize(shell:, env: nil)
        @app = AppService.new(shell: shell, env: env)
        @db = DbService.new(shell: shell, env: env)
      end

      def setup_all
        db.setup
        app.setup
      end

      def build_all
        db.build
        app.build
      end

      def start_all
        db.start
        app.start
      end

      def stop_all
        app.stop
        db.stop
      end

      def restart_all
        stop_all
        start_all
      end

      def teardown_all
        app.teardown
        db.teardown
      end
    end
  end
end
