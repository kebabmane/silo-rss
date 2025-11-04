module Api
  module V1
    class DeviceRegistrationsController < BaseController
      def create
        registration = current_user.device_registrations.find_or_initialize_by(device_token: registration_params[:device_token])
        registration.platform = registration_params[:platform] || "android"
        registration.last_seen_at = Time.current

        if registration.save
          render json: { success: true }, status: :created
        else
          render json: { error: registration.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        registration = current_user.device_registrations.find_by(device_token: params[:device_token])

        if registration
          registration.destroy
          head :no_content
        else
          head :not_found
        end
      end

      private

      def registration_params
        params.require(:device).permit(:device_token, :platform)
      end
    end
  end
end
