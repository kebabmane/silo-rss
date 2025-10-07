module Api
  module V1
    class DailyBriefsController < BaseController
      before_action :set_brief, only: [:show, :mark_read, :mark_unread]

      # GET /api/v1/daily_briefs
      def index
        briefs = current_user.daily_briefs
                            .includes(:daily_brief_schedule)
                            .recent
                            .limit(params[:limit] || 50)
                            .offset(params[:offset] || 0)

        total_count = current_user.daily_briefs.count

        render json: {
          briefs: briefs.map { |brief|
            {
              id: brief.id,
              content: brief.content,
              article_count: brief.article_count,
              generated_at: brief.generated_at,
              emailed_at: brief.emailed_at,
              read: brief.read,
              schedule: {
                id: brief.daily_brief_schedule.id,
                name: brief.daily_brief_schedule.name
              }
            }
          },
          meta: {
            total: total_count,
            limit: params[:limit] || 50,
            offset: params[:offset] || 0,
            unread_count: current_user.daily_briefs.unread.count
          }
        }
      end

      # GET /api/v1/daily_briefs/:id
      def show
        # Automatically mark as read when viewed
        @brief.mark_as_read! unless @brief.read?

        render json: {
          brief: {
            id: @brief.id,
            content: @brief.content,
            article_count: @brief.article_count,
            generated_at: @brief.generated_at,
            emailed_at: @brief.emailed_at,
            read: @brief.read,
            schedule: {
              id: @brief.daily_brief_schedule.id,
              name: @brief.daily_brief_schedule.name
            }
          }
        }
      end

      # PATCH /api/v1/daily_briefs/:id/mark_read
      def mark_read
        @brief.mark_as_read!
        render json: { read: @brief.read }
      end

      # PATCH /api/v1/daily_briefs/:id/mark_unread
      def mark_unread
        @brief.mark_as_unread!
        render json: { read: @brief.read }
      end

      # GET /api/v1/daily_briefs/latest
      def latest
        brief = current_user.daily_briefs.recent.first

        if brief
          # Automatically mark as read when viewed
          brief.mark_as_read! unless brief.read?

          render json: {
            brief: {
              id: brief.id,
              content: brief.content,
              article_count: brief.article_count,
              generated_at: brief.generated_at,
              emailed_at: brief.emailed_at,
              read: brief.read,
              schedule: {
                id: brief.daily_brief_schedule.id,
                name: brief.daily_brief_schedule.name
              }
            }
          }
        else
          render json: { brief: nil }, status: :ok
        end
      end

      private

      def set_brief
        @brief = current_user.daily_briefs.find(params[:id])
      end
    end
  end
end
