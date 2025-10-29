module Admin
  class DailyBriefPromptsController < AdminController
    def index
      @schedules = DailyBriefSchedule
        .includes(:user, :feed_filters, :filtered_feeds)
        .order(created_at: :desc)

      @selected_schedule = if params[:schedule_id].present?
                             @schedules.find_by(id: params[:schedule_id])
                           else
                             @schedules.first
                           end

      if @selected_schedule
        preview = DailyBriefGeneratorService.new(@selected_schedule).prompt_preview
        @prompt = preview[:prompt]
        @articles = preview[:articles]
      end
    rescue LitellmClientService::ConfigurationError => e
      @prompt_error = e.message
    end
  end
end
