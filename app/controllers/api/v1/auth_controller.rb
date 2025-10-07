module Api
  module V1
    class AuthController < ActionController::API
      include ApiAuthentication
      skip_before_action :authenticate_api_user, only: [:login, :register]

      # POST /api/v1/auth/login
      def login
        user = User.find_by(email_address: params[:email])

        if user&.authenticate(params[:password])
          if user.confirmed?
            api_token = user.issue_api_token!
            render json: {
              user: {
                id: user.id,
                email: user.email_address,
                api_token: api_token,
                api_token_expires_at: user.api_token_expires_at
              }
            }, status: :ok
          else
            render json: { error: 'Account pending admin approval' }, status: :forbidden
          end
        else
          render json: { error: 'Invalid email or password' }, status: :unauthorized
        end
      end

      # POST /api/v1/auth/register
      def register
        user = User.new(
          email_address: params[:email],
          password: params[:password],
          password_confirmation: params[:password_confirmation]
        )

        if user.save
          render json: {
            user: {
              id: user.id,
              email: user.email_address,
              confirmed: user.confirmed?
            },
            message: 'Account created. Awaiting admin approval before activation.'
          }, status: :created
        else
          render json: { error: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/auth/refresh
      def refresh
        if (api_token = current_user.issue_api_token!)
          render json: {
            user: {
              id: current_user.id,
              email: current_user.email_address,
              api_token: api_token,
              api_token_expires_at: current_user.api_token_expires_at
            }
          }, status: :ok
        else
          render json: { error: 'Failed to refresh token' }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/auth/logout
      def logout
        current_user.update(api_token: nil, api_token_digest: nil, api_token_expires_at: nil)
        head :no_content
      end
    end
  end
end
