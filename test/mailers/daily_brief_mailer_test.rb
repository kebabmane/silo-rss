require "test_helper"

class DailyBriefMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:alice)
    @schedule = daily_brief_schedules(:one)
    @brief = DailyBrief.create!(
      user: @user,
      daily_brief_schedule: @schedule,
      content: "Summary",
      article_count: 2,
      generated_at: Time.utc(2025, 10, 7, 12, 0, 0)
    )
  end

  test "subject uses user time zone" do
    email = DailyBriefMailer.brief_email(@brief)
    assert_match "Your Daily Brief - October 07, 2025", email.subject
  end

  test "mailer renders" do
    email = DailyBriefMailer.brief_email(@brief)
    assert_emails 1 do
      email.deliver_now
    end
  end
end
