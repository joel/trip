require "rails_helper"

RSpec.describe "users/edit" do
  let(:user) do
    User.create!(
      name: "MyString",
      email: "edit-user@example.com"
    )
  end

  before do
    assign(:user, user)
    controller.define_singleton_method(:current_user) { User.new(roles: [:admin]) }
  end

  it "renders the edit user form" do
    render

    assert_select "form[action=?][method=?]", user_path(user), "post" do
      assert_select "input[name=?]", "user[name]"
      assert_select "input[name=?]", "user[email]"
      assert_select "input[name=?]", "user[roles][]"
    end
  end
end
