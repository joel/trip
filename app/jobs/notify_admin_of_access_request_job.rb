# frozen_string_literal: true

class NotifyAdminOfAccessRequestJob < ApplicationJob
  queue_as :default

  def perform(access_request_id)
    AccessRequestMailer.new_request(access_request_id).deliver_now
  end
end
