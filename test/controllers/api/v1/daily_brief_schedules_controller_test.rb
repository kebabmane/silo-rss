require "test_helper"

module Api
  module V1
    class DailyBriefSchedulesControllerTest < ActionDispatch::IntegrationTest
      include ActiveJob::TestHelper

      setup do
        @user = users(:alice)
        @other_user = users(:bob)
        @schedule = daily_brief_schedules(:one)
        @feed = feeds(:tech_crunch)
      end

      test "index returns schedules for the current user" do
        get api_v1_daily_brief_schedules_url, headers: api_headers(@user), as: :json

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal 1, json["schedules"].size
        assert_equal @schedule.id, json["schedules"].first["id"]
      end

      test "index requires authentication" do
        get api_v1_daily_brief_schedules_url, as: :json
        assert_response :unauthorized
      end

      test "create schedule" do
        assert_difference -> { DailyBriefSchedule.where(user: @user).count } do
          post api_v1_daily_brief_schedules_url,
               params: {
                 schedule: {
                   time_of_day: "09:30",
                   days_of_week: %w[tuesday thursday],
                   email_delivery: true,
                   include_all_feeds: false,
                   summary_length: "short",
                   active: true
                 },
                 feed_ids: [@feed.id]
               },
               headers: api_headers(@user),
               as: :json
        end

        assert_response :created
        json = JSON.parse(response.body)
        schedule = json["schedule"]
        assert_equal ["thursday", "tuesday"], schedule["days_of_week"].sort
        assert_equal false, schedule["include_all_feeds"]
        assert_equal [@feed.id], schedule["feed_ids"]
      end

      test "update schedule" do
        patch api_v1_daily_brief_schedule_url(@schedule),
              params: {
                schedule: {
                  email_delivery: true,
                  summary_length: "detailed"
                }
              },
              headers: api_headers(@user),
              as: :json

        assert_response :success
        @schedule.reload
        assert @schedule.email_delivery
        assert_equal "detailed", @schedule.summary_length
      end

      test "destroy schedule" do
        assert_difference -> { DailyBriefSchedule.where(user: @user).count }, -1 do
          delete api_v1_daily_brief_schedule_url(@schedule),
                 headers: api_headers(@user),
                 as: :json
        end

        assert_response :no_content
      end

      test "generate now enqueues job" do
        assert_enqueued_with(job: DailyBriefGenerationJob, args: [@schedule.id]) do
          post generate_now_api_v1_daily_brief_schedule_url(@schedule),
               headers: api_headers(@user),
               as: :json
        end

        assert_response :accepted
      end

      test "cannot access schedules of other users" do
        get api_v1_daily_brief_schedule_url(@schedule),
            headers: api_headers(@other_user),
            as: :json

        assert_response :not_found
      end

      test "enable schedule" do
        @schedule.update(active: false)
        patch enable_api_v1_daily_brief_schedule_url(@schedule),
              headers: api_headers(@user),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)
        assert json["schedule"]["active"]
      end

      test "disable schedule" do
        @schedule.update(active: true)
        patch disable_api_v1_daily_brief_schedule_url(@schedule),
              headers: api_headers(@user),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)
        assert_not json["schedule"]["active"]
      end
    end
  end
end
