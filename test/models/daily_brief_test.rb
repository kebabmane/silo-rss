require "test_helper"

class DailyBriefTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
    @schedule = DailyBriefSchedule.create!(
      user: @user,
      time_of_day: Time.parse("08:00")
    )
  end

  test "creates brief with valid attributes" do
    brief = DailyBrief.new(
      user: @user,
      daily_brief_schedule: @schedule,
      content: "Test summary",
      article_count: 5,
      generated_at: Time.current
    )

    assert brief.valid?
  end

  test "requires content" do
    brief = DailyBrief.new(
      user: @user,
      daily_brief_schedule: @schedule,
      generated_at: Time.current
    )

    assert_not brief.valid?
  end

  test "requires generated_at" do
    brief = DailyBrief.new(
      user: @user,
      daily_brief_schedule: @schedule,
      content: "Test"
    )

    assert_not brief.valid?
  end

  test "defaults read to false" do
    brief = DailyBrief.create!(
      user: @user,
      daily_brief_schedule: @schedule,
      content: "Test",
      generated_at: Time.current
    )

    assert_equal false, brief.read?
  end

  test "mark_as_read! sets read to true" do
    brief = DailyBrief.create!(
      user: @user,
      daily_brief_schedule: @schedule,
      content: "Test",
      generated_at: Time.current
    )

    brief.mark_as_read!
    assert brief.read?
  end

  test "mark_as_unread! sets read to false" do
    brief = DailyBrief.create!(
      user: @user,
      daily_brief_schedule: @schedule,
      content: "Test",
      generated_at: Time.current,
      read: true
    )

    brief.mark_as_unread!
    assert_not brief.read?
  end

  test "emailed? returns true when emailed_at is set" do
    brief = DailyBrief.create!(
      user: @user,
      daily_brief_schedule: @schedule,
      content: "Test",
      generated_at: Time.current,
      emailed_at: Time.current
    )

    assert brief.emailed?
  end
end
