# frozen_string_literal: true

class BackfillJackAgent < ActiveRecord::Migration[8.1]
  def up
    jack_user = User.find_by(email: "jack@system.local")
    return unless jack_user

    Agent.find_or_create_by!(slug: "jack") do |a|
      a.name = "Jack"
      a.user = jack_user
    end
  end

  def down
    Agent.find_by(slug: "jack")&.destroy
  end
end
