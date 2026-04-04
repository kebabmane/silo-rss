module Api
  module V1
    class ProfilesController < BaseController
      # GET /api/v1/profile
      def show
        render json: {
          user: {
            id: current_user.id,
            email: current_user.email_address,
            time_zone: current_user.time_zone,
            confirmed: current_user.confirmed?,
            admin: current_user.admin?
          }
        }, status: :ok
      end

      # PATCH /api/v1/profile
      def update
        if current_user.update(profile_params)
          render json: {
            user: {
              id: current_user.id,
              email: current_user.email_address,
              time_zone: current_user.time_zone,
              confirmed: current_user.confirmed?,
              admin: current_user.admin?
            },
            message: "Profile updated successfully."
          }, status: :ok
        else
          render json: { error: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def profile_params
        params.require(:user).permit(:time_zone)
      end
    end
  end
end
