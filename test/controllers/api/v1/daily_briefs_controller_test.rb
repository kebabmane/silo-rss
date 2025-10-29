require "test_helper"

module Api
  module V1
    class DailyBriefsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:alice)
        @user.ensure_api_token!
        @schedule = daily_brief_schedules(:one)
        @brief = daily_briefs(:one)
      end

      test "index returns schedule display name" do
        get api_v1_daily_briefs_url,
            headers: api_headers(@user),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)
        first_brief = json["briefs"].first

        assert_equal @schedule.display_name, first_brief.dig("schedule", "name")
      end

      test "show returns schedule display name" do
        get api_v1_daily_brief_url(@brief),
            headers: api_headers(@user),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert_equal @schedule.display_name, json.dig("brief", "schedule", "name")
      end

      test "latest returns schedule display name" do
        get latest_api_v1_daily_briefs_url,
            headers: api_headers(@user),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert_equal @schedule.display_name, json.dig("brief", "schedule", "name")
      end
    end
  end
end
