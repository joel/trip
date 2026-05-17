#!/usr/bin/env ruby

require "thor"
require_relative "services/helpers"
require_relative "services/app-cmd/app_commands"
require_relative "services/db-cmd/db_commands"
require_relative "services/mail-cmd/mail_commands"
require_relative "services/storage-cmd/storage_commands"
require_relative "services/services_commands"

Dir.chdir(AppCLI::ROOT) unless Dir.pwd == AppCLI::ROOT

module AppCLI
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "app ACTION [ENV]", "Manage the application container"
    long_desc "Actions: start, stop, build, logs, status, connect, console, exec, migrate, " \
              "schema_dump, setup, prepare, teardown, rebuild, restart"
    subcommand "app", Services::AppCommands

    desc "db ACTION [ENV]", "Manage the database container"
    long_desc "Actions: start, stop, build, logs, status, connect, console, exec, setup, " \
              "prepare, teardown, rebuild, restart, reset"
    subcommand "db", Services::DbCommands

    desc "mail ACTION", "Manage the local mail service"
    long_desc "Actions: start, stop, logs, status"
    subcommand "mail", Services::MailCommands

    desc "storage ACTION", "Manage the local SeaweedFS storage service"
    long_desc "Actions: start, stop, logs, status, create_bucket"
    subcommand "storage", Services::StorageCommands

    desc "services ACTION [ENV]", "Orchestrate all services together"
    long_desc "Actions: list, start, stop, build, setup, status, teardown, restart"
    subcommand "services", Services::ServicesCommands

    def self.help(shell, subcommand = false) # rubocop:disable Style/OptionalBooleanParameter
      super
      shell.say ""
      shell.say "ACTION: (start, stop, build, logs, connect, console, reset, ...)"
      shell.say "ENV: dev|development (default), prod|production"
    end
  end
end

AppCLI::CLI.start(ARGV)
