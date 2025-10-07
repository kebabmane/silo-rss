class DailyBriefMailer < ApplicationMailer
  # Send a daily brief email to a user
  def brief_email(brief)
    @brief = brief
    @user = brief.user
    @schedule = brief.daily_brief_schedule

    mail(
      to: @user.email_address,
      subject: "Your Daily Brief - #{brief.generated_at.strftime('%B %d, %Y')}"
    ) do |format|
      format.html
      format.text
    end

    # Mark as emailed
    @brief.update(emailed_at: Time.current)
  end
end
