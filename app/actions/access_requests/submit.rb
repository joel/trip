# frozen_string_literal: true

module AccessRequests
  class Submit < BaseAction
    def call(params:)
      access_request = yield persist(params)
      yield emit_event(access_request)
      Success(access_request)
    end

    private

    def persist(params)
      ar = AccessRequest.create!(email: params[:email])
      Success(ar)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    rescue ActiveRecord::RecordNotUnique
      ar = AccessRequest.new(email: params[:email])
      ar.errors.add(:email, "already has a pending request or approved invitation")
      Failure(ar.errors)
    end

    def emit_event(access_request)
      Rails.event.notify("access_request.submitted",
                         access_request_id: access_request.id, email: access_request.email)
      Success()
    end
  end
end
