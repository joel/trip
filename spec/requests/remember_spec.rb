# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Remember me configuration" do
  let(:rodauth_class) { RodauthApp.rodauth }
  let(:rodauth_instance) { rodauth_class.allocate }

  it "has remember feature enabled" do
    expect(rodauth_class.features).to include(:remember)
  end

  it "uses user_remember_keys table" do
    expect(rodauth_instance.remember_table).to eq(:user_remember_keys)
  end

  it "sets remember deadline to 30 days" do
    expect(rodauth_instance.remember_deadline_interval).to eq({ days: 30 })
  end

  it "extends remember deadline on activity" do
    expect(rodauth_instance.extend_remember_deadline?).to be true
  end
end
