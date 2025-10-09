class DailyBriefMailer < ApplicationMailer
  # Send a daily brief email to a user
  def brief_email(brief)
    @brief = brief
    @user = brief.user
    @schedule = brief.daily_brief_schedule

    local_zone = @user.time_zone_or_default
    local_generated_at = @brief.generated_at.in_time_zone(local_zone)

    message = nil
    Time.use_zone(local_zone) do
      message = mail(
        to: @user.email_address,
        subject: "Your Daily Brief - #{local_generated_at.strftime('%B %d, %Y')}"
      ) do |format|
        format.html
        format.text
      end

      # Mark as emailed
      @brief.update(emailed_at: Time.current)
    end

    message
  end
end
