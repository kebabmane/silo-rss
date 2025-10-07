class DailyBriefSchedulerJob < ApplicationJob
  queue_as :default

  # Check all schedules and enqueue generation jobs for those that should run
  def perform
    current_time = Time.current

    # Find all active schedules
    DailyBriefSchedule.active.find_each do |schedule|
      # Check if this schedule should run now
      if should_generate_brief?(schedule, current_time)
        DailyBriefGenerationJob.perform_later(schedule.id)
      end
    end
  end

  private

  def should_generate_brief?(schedule, current_time)
    # Check if schedule is due to run
    return false unless schedule.time_to_generate?(current_time)

    # Check if we've already generated a brief in this hour
    !brief_already_generated_this_hour?(schedule, current_time)
  end

  def brief_already_generated_this_hour?(schedule, current_time)
    schedule.daily_briefs
            .where("generated_at >= ? AND generated_at < ?",
                   current_time.beginning_of_hour,
                   current_time.end_of_hour)
            .exists?
  end
end
