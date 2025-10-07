class DailyBriefSchedulesController < ApplicationController
  before_action :set_schedule, only: [:edit, :update, :destroy, :generate_now]

  def index
    @schedules = Current.user.daily_brief_schedules.order(created_at: :desc)
  end

  def new
    @schedule = Current.user.daily_brief_schedules.build
  end

  def create
    @schedule = Current.user.daily_brief_schedules.build(schedule_params)

    if @schedule.save
      # Handle feed filters if not including all feeds
      unless @schedule.include_all_feeds?
        update_feed_filters(@schedule, params[:feed_ids] || [])
      end

      redirect_to daily_brief_schedules_path, notice: "Daily brief schedule created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @schedule.update(schedule_params)
      # Update feed filters
      unless @schedule.include_all_feeds?
        update_feed_filters(@schedule, params[:feed_ids] || [])
      else
        @schedule.feed_filters.destroy_all
      end

      redirect_to daily_brief_schedules_path, notice: "Daily brief schedule updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @schedule.destroy
    redirect_to daily_brief_schedules_path, notice: "Daily brief schedule deleted successfully."
  end

  def generate_now
    # Queue the generation job
    job = DailyBriefGenerationJob.perform_later(@schedule.id)

    redirect_to daily_briefs_path, notice: "Daily brief generation started. Check back in a moment to see your new brief!"
  end

  private

  def set_schedule
    @schedule = Current.user.daily_brief_schedules.find(params[:id])
  end

  def schedule_params
    params.require(:daily_brief_schedule).permit(
      :time_of_day,
      :email_delivery,
      :include_all_feeds,
      :summary_length,
      :active,
      days_of_week: []
    )
  end

  def update_feed_filters(schedule, feed_ids)
    # Remove existing filters
    schedule.feed_filters.destroy_all

    # Create new filters
    feed_ids.reject(&:blank?).each do |feed_id|
      schedule.feed_filters.create(feed_id: feed_id)
    end
  end
end
