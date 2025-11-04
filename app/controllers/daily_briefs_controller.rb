class DailyBriefsController < ApplicationController
  before_action :set_brief, only: [:show, :mark_read, :mark_unread]

  def index
    briefs_query = Current.user.daily_briefs
                          .includes(:daily_brief_schedule)
                          .recent
    @pagy, @briefs = pagy(briefs_query, items: 20)
  end

  def show
    # Automatically mark as read when viewed
    @brief.mark_as_read! unless @brief.read?
  end

  def mark_read
    @brief.mark_as_read!
    redirect_back fallback_location: daily_briefs_path, notice: "Brief marked as read."
  end

  def mark_unread
    @brief.mark_as_unread!
    redirect_back fallback_location: daily_briefs_path, notice: "Brief marked as unread."
  end

  private

  def set_brief
    @brief = Current.user.daily_briefs.find(params[:id])
  end
end
