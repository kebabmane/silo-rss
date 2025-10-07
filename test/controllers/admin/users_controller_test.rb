require "test_helper"

module Admin
  class UsersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:alice)
      @pending = users(:pending)
      @user = users(:bob)
    end

    test "requires admin authentication" do
      login_as @user

      get admin_users_url

      assert_redirected_to dashboard_path
      assert_equal "You are not authorized to access that area.", flash[:alert]
    end

    test "shows user list to admins" do
      login_as @admin

      get admin_users_url

      assert_response :success
      assert_select "h1", text: "User Administration"
    end

    test "allows admin to confirm user" do
      login_as @admin

      assert_nil @pending.confirmed_at

      patch confirm_admin_user_url(@pending)

      assert_redirected_to admin_users_url
      assert_equal "User confirmed successfully.", flash[:notice]
      assert @pending.reload.confirmed?
      assert_equal @admin, @pending.confirmed_by
    end

    test "allows admin to toggle admin flag" do
      login_as @admin

      refute @user.admin?

      patch admin_user_url(@user), params: { user: { admin: true } }

      assert_redirected_to admin_users_url
      assert_equal "User updated successfully.", flash[:notice]
      assert @user.reload.admin?
    end
  end
end
