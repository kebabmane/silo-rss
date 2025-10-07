require "test_helper"

class DailyBriefScheduleTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
  end

  test "should create schedule with valid attributes" do
    schedule = DailyBriefSchedule.new(
      user: @user,
      time_of_day: Time.parse("08:00"),
      days_of_week: ["monday", "wednesday", "friday"],
      email_delivery: true,
      include_all_feeds: true,
      summary_length: "medium"
    )

    assert schedule.valid?
  end

  test "requires time_of_day" do
    schedule = DailyBriefSchedule.new(user: @user, time_of_day: nil)
    assert_not schedule.valid?
  end

  test "validates summary_length options" do
    schedule = DailyBriefSchedule.new(user: @user, time_of_day: Time.parse("08:00"))

    schedule.summary_length = "invalid"
    assert_not schedule.valid?

    schedule.summary_length = "short"
    assert schedule.valid?

    schedule.summary_length = "medium"
    assert schedule.valid?

    schedule.summary_length = "detailed"
    assert schedule.valid?
  end

  test "validates days_of_week format" do
    schedule = DailyBriefSchedule.new(
      user: @user,
      time_of_day: Time.parse("08:00"),
      days_of_week: ["monday", "invalidday"]
    )

    assert_not schedule.valid?
    assert_includes schedule.errors[:days_of_week], "contains invalid day(s): invalidday"
  end

  test "should_run_on? returns true for matching day" do
    schedule = DailyBriefSchedule.create!(
      user: @user,
      time_of_day: Time.parse("08:00"),
      days_of_week: ["monday", "wednesday"]
    )

    monday = Date.new(2025, 10, 6) # A Monday
    wednesday = Date.new(2025, 10, 8) # A Wednesday
    tuesday = Date.new(2025, 10, 7) # A Tuesday

    assert schedule.should_run_on?(monday)
    assert schedule.should_run_on?(wednesday)
    assert_not schedule.should_run_on?(tuesday)
  end

  test "should_run_on? returns true every day when days_of_week is empty" do
    schedule = DailyBriefSchedule.create!(
      user: @user,
      time_of_day: Time.parse("08:00"),
      days_of_week: []
    )

    assert schedule.should_run_on?(Date.today)
    assert schedule.should_run_on?(Date.tomorrow)
  end

  test "should_run_on? returns false when inactive" do
    schedule = DailyBriefSchedule.create!(
      user: @user,
      time_of_day: Time.parse("08:00"),
      active: false
    )

    assert_not schedule.should_run_on?(Date.today)
  end

  test "feeds_to_include returns all user feeds when include_all_feeds is true" do
    schedule = DailyBriefSchedule.create!(
      user: @user,
      time_of_day: Time.parse("08:00"),
      include_all_feeds: true
    )

    assert_equal @user.feeds, schedule.feeds_to_include
  end

  test "feeds_to_include returns filtered feeds when include_all_feeds is false" do
    schedule = DailyBriefSchedule.create!(
      user: @user,
      time_of_day: Time.parse("08:00"),
      include_all_feeds: false
    )

    feed = feeds(:tech_crunch)
    schedule.feed_filters.create!(feed: feed)

    assert_equal [feed], schedule.feeds_to_include
  end
end
