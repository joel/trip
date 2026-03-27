# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Rodauth stores account_id in session via session_key
      user_id = request.session[:account_id]
      user = User.find_by(id: user_id) if user_id
      user || reject_unauthorized_connection
    end
  end
end
