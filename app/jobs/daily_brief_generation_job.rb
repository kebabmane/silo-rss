class DailyBriefGenerationJob < ApplicationJob
  queue_as :default

  # Generate a daily brief for a specific schedule
  def perform(schedule_id)
    schedule = DailyBriefSchedule.find_by(id: schedule_id)
    unless schedule
      Rails.logger.error("Daily brief schedule #{schedule_id} not found")
      raise ActiveRecord::RecordNotFound, "Schedule #{schedule_id} not found"
    end

    # Check if LiteLLM is configured
    unless LitellmSetting.configured?
      error_msg = "Cannot generate daily brief: LiteLLM not configured"
      Rails.logger.error(error_msg)
      raise DailyBriefGeneratorService::Error, error_msg
    end

    # Generate the brief
    generator = DailyBriefGeneratorService.new(schedule)
    brief = generator.generate

    # Send email if requested
    if schedule.email_delivery? && brief.article_count > 0
      DailyBriefMailer.brief_email(brief).deliver_later
    end

    Rails.logger.info("Generated daily brief #{brief.id} for user #{schedule.user_id}")
  rescue DailyBriefGeneratorService::Error => e
    Rails.logger.error("Failed to generate daily brief for schedule #{schedule_id}: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace
    # Re-raise to mark job as failed
    raise
  rescue => e
    Rails.logger.error("Unexpected error generating daily brief for schedule #{schedule_id}: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace
    # Re-raise to mark job as failed
    raise
  end
end
