# frozen_string_literal: true

module AccessRequests
  class Reject < BaseAction
    def call(access_request:, user:)
      yield review(access_request, user)
      yield emit_event(access_request)
      Success(access_request)
    end

    private

    def review(access_request, user)
      access_request.update!(status: :rejected, reviewed_by: user, reviewed_at: Time.current)
      Success()
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    def emit_event(access_request)
      Rails.event.notify("access_request.rejected",
                         access_request_id: access_request.id, email: access_request.email)
      Success()
    end
  end
end
