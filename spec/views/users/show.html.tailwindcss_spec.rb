require "rails_helper"

RSpec.describe "users/show" do
  before do
    assign(:user, User.create!(
                    name: "Name",
                    email: "show-user@example.com"
                  ))
    controller.define_singleton_method(:current_user) { User.new(roles: [:admin]) }
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
  end
end
