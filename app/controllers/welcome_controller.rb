# frozen_string_literal: true

class WelcomeController < ApplicationController
  def home
    if (target = post_login_target_for(current_user))
      redirect_to(target) and return
    end

    render Views::Welcome::Home.new
  end

  private

  def post_login_target_for(user)
    return unless user

    trips = user.trips
    count = trips.count
    return nil if count.zero?
    return trip_path(trips.first) if count == 1

    started = trips.where(state: :started).order(updated_at: :desc).first
    started ? trip_path(started) : trips_path
  end
end
