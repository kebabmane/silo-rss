require "test_helper"

class DailyBriefSchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    sign_in_as @user
  end

  test "should get index" do
    get daily_brief_schedules_url
    assert_response :success
  end

  test "should get new" do
    get new_daily_brief_schedule_url
    assert_response :success
  end

  test "should create daily_brief_schedule" do
    assert_difference("DailyBriefSchedule.count") do
      post daily_brief_schedules_url, params: {
        daily_brief_schedule: {
          time_of_day: "08:00",
          days_of_week: ["monday", "wednesday"],
          email_delivery: true,
          include_all_feeds: true,
          summary_length: "medium",
          active: true
        }
      }
    end

    assert_redirected_to daily_brief_schedules_url
  end

  test "should get edit" do
    schedule = DailyBriefSchedule.create!(user: @user, time_of_day: Time.parse("08:00"))
    get edit_daily_brief_schedule_url(schedule)
    assert_response :success
  end

  test "should update daily_brief_schedule" do
    schedule = DailyBriefSchedule.create!(user: @user, time_of_day: Time.parse("08:00"))

    patch daily_brief_schedule_url(schedule), params: {
      daily_brief_schedule: {
        time_of_day: "09:00"
      }
    }

    assert_redirected_to daily_brief_schedules_url
    schedule.reload
    assert_equal 9, schedule.time_of_day.hour
  end

  test "should destroy daily_brief_schedule" do
    schedule = DailyBriefSchedule.create!(user: @user, time_of_day: Time.parse("08:00"))

    assert_difference("DailyBriefSchedule.count", -1) do
      delete daily_brief_schedule_url(schedule)
    end

    assert_redirected_to daily_brief_schedules_url
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
