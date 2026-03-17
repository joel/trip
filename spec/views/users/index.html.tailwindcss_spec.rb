require "rails_helper"

RSpec.describe "users/index" do
  before do
    assign(:users, [
             User.create!(
               name: "Name",
               email: "user-one@example.com"
             ),
             User.create!(
               name: "Name",
               email: "user-two@example.com"
             )
           ])
    controller.define_singleton_method(:current_user) { User.new(roles: [:admin]) }
  end

  it "renders a list of users" do
    render
    cell_selector = "div>p"
    assert_select cell_selector, text: Regexp.new("Name"), count: 2
  end
end
