module Api
  module V1
    class PasswordsController < ActionController::API
      # POST /api/v1/passwords
      def create
        if (user = User.find_by(email_address: params[:email]))
          token = user.generate_password_reset_token!
          PasswordsMailer.reset(user, token).deliver_later
        end

        render json: {
          message: "If your account exists, we've emailed password reset instructions."
        }, status: :ok
      end

      # PATCH /api/v1/passwords/:token
      def update
        password = params[:password]
        confirmation = params[:password_confirmation]

        if password.blank? || confirmation.blank?
          render json: { error: "Password and confirmation are required." }, status: :unprocessable_entity
          return
        end

        user = User.find_by_password_reset_token!(params[:token])

        if user.update(password: password, password_confirmation: confirmation)
          user.clear_password_reset_token!
          render json: { message: "Password has been reset." }, status: :ok
        else
          render json: { error: user.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        render json: { error: "Password reset token is invalid or has expired." }, status: :unprocessable_entity
      end
    end
  end
end
