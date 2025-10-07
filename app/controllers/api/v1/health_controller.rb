module Api
  module V1
    class HealthController < ActionController::API
      # GET /api/v1/health
      def show
        render json: {
          status: "ok",
          message: "Feed Reader API is running",
          timestamp: Time.current.iso8601,
          version: "1.0.0"
        }, status: :ok
      end
    end
  end
end
