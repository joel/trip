# frozen_string_literal: true

require "rails_helper"

RSpec.describe "user_remember_keys table" do
  it "exists with the expected columns" do
    columns = ActiveRecord::Base.connection.columns(:user_remember_keys)
    column_names = columns.map(&:name)

    expect(column_names).to contain_exactly("id", "key", "deadline")
  end

  it "has a foreign key to users" do
    foreign_keys = ActiveRecord::Base.connection.foreign_keys(:user_remember_keys)
    expect(foreign_keys.map(&:to_table)).to include("users")
  end
end
