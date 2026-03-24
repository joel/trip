# frozen_string_literal: true

require "sequel/core"

namespace :auth do
  desc "Generate a magic login link for a user. Usage: rake auth:login_link[user@example.com]"
  task :login_link, [:email] => :environment do |_t, args|
    abort "Usage: rake auth:login_link[user@example.com]" unless args[:email]

    user = User.find_by(email: args[:email])
    abort "No user found with email: #{args[:email]}" unless user

    db = Sequel.sqlite(extensions: :activerecord_connection, keep_reference: false)
    db[:user_email_auth_keys].where(id: user.id).delete

    key = SecureRandom.hex(32)
    db[:user_email_auth_keys].insert( # rubocop:disable Rails/SkipsModelValidations -- Sequel table, no AR model
      id: user.id,
      key: key,
      deadline: 1.hour.from_now,
      email_last_sent: Time.current
    )

    host = ENV.fetch("APP_URL") { Rails.application.routes.default_url_options[:host] || "localhost:3000" }
    scheme = host.start_with?("localhost") ? "http" : "https"
    host = "#{scheme}://#{host}" unless host.start_with?("http")

    puts "\nLogin link for #{user.email} (expires in 1 hour):"
    puts "#{host}/email-auth?key=#{user.id}_#{key}\n\n"
  end

  desc "Verify a user account. Usage: rake auth:verify[user@example.com]"
  task :verify, [:email] => :environment do |_t, args|
    abort "Usage: rake auth:verify[user@example.com]" unless args[:email]

    user = User.find_by(email: args[:email])
    abort "No user found with email: #{args[:email]}" unless user

    db = Sequel.sqlite(extensions: :activerecord_connection, keep_reference: false)

    # Rodauth open status = 2 (verified)
    if user.status == 2
      puts "#{user.email} is already verified (status: #{user.status})"
    else
      user.update!(status: 2)
      db[:user_verification_keys].where(id: user.id).delete
      puts "#{user.email} is now verified (status: 2)"
    end
  end
end
