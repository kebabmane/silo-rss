require "test_helper"

class DailyBriefsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    sign_in_as @user

    @schedule = DailyBriefSchedule.create!(user: @user, time_of_day: Time.parse("08:00"))
    @brief = DailyBrief.create!(
      user: @user,
      daily_brief_schedule: @schedule,
      content: "Test brief content",
      generated_at: Time.current
    )
  end

  test "should get index" do
    get daily_briefs_url
    assert_response :success
  end

  test "should show brief" do
    get daily_brief_url(@brief)
    assert_response :success
  end

  test "should mark brief as read when shown" do
    assert_not @brief.read?

    get daily_brief_url(@brief)

    @brief.reload
    assert @brief.read?
  end

  test "should mark brief as read via action" do
    patch mark_read_daily_brief_url(@brief)

    @brief.reload
    assert @brief.read?
  end

  test "should mark brief as unread via action" do
    @brief.update!(read: true)

    patch mark_unread_daily_brief_url(@brief)

    @brief.reload
    assert_not @brief.read?
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
