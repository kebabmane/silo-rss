require "test_helper"

class DailyBriefSchedulerJobTest < ActiveJob::TestCase
  setup do
    @user = users(:alice)
  end

  test "enqueues generation jobs for due schedules" do
    # Create a schedule that should run now in user's timezone
    Time.use_zone(@user.time_zone) do
      travel_to Time.zone.parse("2025-10-06 08:15:00") do # Monday 8:15 AM
        schedule = DailyBriefSchedule.create!(
          user: @user,
          time_of_day: Time.zone.parse("08:00"),
          days_of_week: ["monday"]
        )

        assert_enqueued_with(job: DailyBriefGenerationJob, args: [schedule.id]) do
          DailyBriefSchedulerJob.perform_now
        end
      end
    end
  end

  test "does not enqueue for inactive schedules" do
    Time.use_zone(@user.time_zone) do
      travel_to Time.zone.parse("2025-10-06 08:15:00") do
        schedule = DailyBriefSchedule.create!(
          user: @user,
          time_of_day: Time.zone.parse("08:00"),
          active: false
        )

        assert_no_enqueued_jobs do
          DailyBriefSchedulerJob.perform_now
        end
      end
    end
  end

  test "does not enqueue if brief already generated this hour" do
    Time.use_zone(@user.time_zone) do
      travel_to Time.zone.parse("2025-10-06 08:15:00") do
        schedule = DailyBriefSchedule.create!(
          user: @user,
          time_of_day: Time.zone.parse("08:00")
        )

        # Create a brief already generated this hour
        DailyBrief.create!(
          user: @user,
          daily_brief_schedule: schedule,
          content: "Already generated",
          generated_at: Time.zone.parse("2025-10-06 08:05:00")
        )

        assert_no_enqueued_jobs do
          DailyBriefSchedulerJob.perform_now
        end
      end
    end
  end

  test "does not enqueue for wrong time" do
    Time.use_zone(@user.time_zone) do
      travel_to Time.zone.parse("2025-10-06 09:15:00") do # 9:15 AM, schedule is for 8:00
        schedule = DailyBriefSchedule.create!(
          user: @user,
          time_of_day: Time.zone.parse("08:00")
        )

        assert_no_enqueued_jobs do
          DailyBriefSchedulerJob.perform_now
        end
      end
    end
  end
end
