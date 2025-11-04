module Api
  module V1
    class DailyBriefSchedulesController < BaseController
      before_action :set_schedule, only: [:show, :update, :destroy, :generate_now, :enable, :disable]

      def index
        schedules = current_user.daily_brief_schedules.order(created_at: :desc).includes(:feed_filters)
        render json: {
          schedules: schedules.map { |schedule| schedule_json(schedule) }
        }
      end

      def show
        render json: { schedule: schedule_json(@schedule) }
      end

      def create
        schedule = current_user.daily_brief_schedules.new
        assign_schedule_attributes(schedule)
        if schedule.errors.any?
          return render json: { error: schedule.errors.full_messages }, status: :unprocessable_entity
        end

        if schedule.save
          update_feed_filters(schedule)
          render json: { schedule: schedule_json(schedule) }, status: :created
        else
          render json: { error: schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        assign_schedule_attributes(@schedule)
        if @schedule.errors.any?
          return render json: { error: @schedule.errors.full_messages }, status: :unprocessable_entity
        end

        if @schedule.save
          update_feed_filters(@schedule)
          render json: { schedule: schedule_json(@schedule) }
        else
          render json: { error: @schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @schedule.destroy
        head :no_content
      end

      def generate_now
        DailyBriefGenerationJob.perform_later(@schedule.id)
        head :accepted
      end

      def enable
        @schedule.update(active: true)
        render json: { schedule: schedule_json(@schedule) }
      end

      def disable
        @schedule.update(active: false)
        render json: { schedule: schedule_json(@schedule) }
      end

      private

      def set_schedule
        @schedule = current_user.daily_brief_schedules.find(params[:id])
      end

      def schedule_params
        params.require(:schedule).permit(
          :time_of_day,
          :email_delivery,
          :include_all_feeds,
          :summary_length,
          :active,
          days_of_week: []
        )
      end

      def feed_ids
        Array(params[:feed_ids]).map(&:to_i).reject(&:zero?)
      end

      def assign_schedule_attributes(schedule)
        attrs = schedule_params

        if attrs[:time_of_day].present?
          parsed_time = parse_time_of_day(attrs[:time_of_day])
          if parsed_time
            schedule.time_of_day = parsed_time
          else
            schedule.errors.add(:time_of_day, "is invalid")
          end
        end

        schedule.email_delivery = attrs[:email_delivery] unless attrs[:email_delivery].nil?
        schedule.include_all_feeds = attrs[:include_all_feeds] unless attrs[:include_all_feeds].nil?
        schedule.summary_length = attrs[:summary_length] if attrs[:summary_length].present?
        schedule.active = attrs[:active] unless attrs[:active].nil?
        schedule.days_of_week = Array(attrs[:days_of_week]).map { |day| day.to_s.downcase }
      end

      def update_feed_filters(schedule)
        if schedule.include_all_feeds?
          schedule.feed_filters.destroy_all
          return
        end

        ids = feed_ids
        schedule.feed_filters.destroy_all
        ids.each do |feed_id|
          schedule.feed_filters.create(feed_id: feed_id)
        end
      end

      def schedule_json(schedule)
        {
          id: schedule.id,
          time_of_day: schedule.time_of_day&.strftime("%H:%M"),
          days_of_week: schedule.days_of_week,
          email_delivery: schedule.email_delivery,
          include_all_feeds: schedule.include_all_feeds,
          summary_length: schedule.summary_length,
          active: schedule.active,
          feed_ids: schedule.include_all_feeds? ? [] : schedule.feed_filters.pluck(:feed_id),
          created_at: schedule.created_at,
          updated_at: schedule.updated_at
        }
      end

      def parse_time_of_day(value)
        return value if value.is_a?(Time)

        Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
