class DailyBriefPushNotification < ApplicationPushNotification
  # Build notification for a daily brief
  def initialize(user, brief)
    @user = user
    @brief = brief

    formatted_date = brief.generated_at.in_time_zone(user.time_zone).strftime('%B %d')

    super(
      title: "New daily brief ready",
      body: "Your summary for #{formatted_date} is available.",
      badge: 1,
      thread_id: "daily_briefs"
    )
  end
end
