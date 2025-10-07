require "test_helper"

class DailyBriefGenerationJobTest < ActiveJob::TestCase
  setup do
    @user = users(:alice)
    @schedule = DailyBriefSchedule.create!(
      user: @user,
      time_of_day: Time.parse("08:00")
    )

    LitellmSetting.instance.update!(
      enabled: true,
      server_url: "http://localhost:4000",
      default_model: "gpt-3.5-turbo"
    )
  end

  test "generates brief for valid schedule" do
    stub_request(:post, "http://localhost:4000/chat/completions")
      .to_return(
        status: 200,
        body: { choices: [{ message: { content: "Summary" } }] }.to_json
      )

    assert_difference "DailyBrief.count", 1 do
      DailyBriefGenerationJob.perform_now(@schedule.id)
    end
  end

  test "does nothing when schedule not found" do
    assert_no_difference "DailyBrief.count" do
      DailyBriefGenerationJob.perform_now(99999)
    end
  end

  test "does nothing when LiteLLM not configured" do
    LitellmSetting.instance.update!(enabled: false)

    assert_no_difference "DailyBrief.count" do
      DailyBriefGenerationJob.perform_now(@schedule.id)
    end
  end

  test "enqueues email delivery when email_delivery is true and articles present" do
    @schedule.update!(email_delivery: true)

    feed = feeds(:tech_crunch)
    @user.subscriptions.create!(feed: feed)
    feed.articles.create!(
      title: "Test",
      content: "Content",
      url: "http://test.com",
      guid: "test",
      published_at: 1.hour.ago
    )

    stub_request(:post, "http://localhost:4000/chat/completions")
      .to_return(
        status: 200,
        body: { choices: [{ message: { content: "Summary" } }] }.to_json
      )

    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      DailyBriefGenerationJob.perform_now(@schedule.id)
    end
  end
end
