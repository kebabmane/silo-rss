module Api
  module V1
    class DeviceRegistrationsController < BaseController
      def create
        # Always return success for idempotency, but only save if enabled
        render_success_response

        # Only actually register the device if push notifications are enabled
        return unless Setting.push_notifications_enabled?

        registration = current_user.device_registrations.find_or_initialize_by(device_token: registration_params[:device_token])
        registration.platform = registration_params[:platform] || "android"
        registration.last_seen_at = Time.current
        registration.save
      end

      def destroy
        # Always return success for idempotency
        head :no_content

        # Only destroy if push notifications are enabled
        return unless Setting.push_notifications_enabled?

        registration = current_user.device_registrations.find_by(device_token: params[:device_token])
        registration&.destroy
      end

      private

      def registration_params
        params.require(:device).permit(:device_token, :platform)
      end

      def render_success_response
        render json: { success: true }, status: :created
      end
    end
  end
end
