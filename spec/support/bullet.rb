# frozen_string_literal: true

if Bullet.enable?
  RSpec.configure do |config|
    config.around do |example|
      Bullet.start_request
      example.run
    ensure
      Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
    end
  end
end
