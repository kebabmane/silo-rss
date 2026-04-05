# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include ApiAuthentication

      rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

      # Enable ETag-based caching for mobile apps
      before_action :set_cache_headers

      private

      def record_not_found(error)
        render json: { error: error.message }, status: :not_found
      end

      def record_invalid(error)
        render json: { error: error.message, details: error.record.errors }, status: :unprocessable_entity
      end

      def set_cache_headers
        # Allow conditional requests (If-None-Match)
        response.headers["Cache-Control"] = "private, max-age=0, must-revalidate"
      end

      # Helper method to enable ETag for specific actions
      def enable_etag(record_or_collection)
        fresh_when(etag: record_or_collection, public: false)
      end
    end
  end
end
