require "test_helper"

module Admin
  class DailyBriefPromptsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:alice)
      @schedule = daily_brief_schedules(:one)
      LitellmSetting.instance.update!(
        enabled: true,
        server_url: "http://localhost:4000",
        default_model: "gpt-3.5-turbo"
      )
    end

    test "requires admin access" do
      login_as users(:bob)

      get admin_daily_brief_prompts_path

      assert_redirected_to dashboard_path
      assert_equal "You are not authorized to access that area.", flash[:alert]
    end

    test "renders prompt preview for admins" do
      login_as @admin

      get admin_daily_brief_prompts_path

      assert_response :success
      assert_select "h1", text: /Daily Brief Prompt Preview/
      assert_select "#prompt-preview"
    end

    test "can view specific schedule prompt" do
      login_as @admin

      get admin_daily_brief_prompts_path(schedule_id: @schedule.id)

      assert_response :success
      assert_select "select[name='schedule_id'] option[selected='selected'][value='#{@schedule.id}']"
    end
  end
end
