module Api
  module V1
    class AuthController < ActionController::API
      include ApiAuthentication
      skip_before_action :authenticate_api_user, only: [ :login, :register ]

      # POST /api/v1/auth/login
      def login
        user = User.authenticate_by(email_address: params[:email], password: params[:password])

        if user
          # Check if admin confirmation is required (same logic as web login)
          if Setting.require_admin_confirmation? && !user.confirmed?
            render json: { error: "Account pending admin approval" }, status: :forbidden
          else
            api_token = user.issue_api_token!
            render json: {
              user: {
                id: user.id,
                email: user.email_address,
                api_token: api_token,
                api_token_expires_at: user.api_token_expires_at
              }
            }, status: :ok
          end
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
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
          # Auto-confirm if admin confirmation is not required (same as web registration)
          unless Setting.require_admin_confirmation?
            user.confirm!
          end

          render json: {
            user: {
              id: user.id,
              email: user.email_address,
              confirmed: user.confirmed?
            },
            message: user.confirmed? ? "Account created and confirmed." : "Account created. Awaiting admin approval before activation."
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
          render json: { error: "Failed to refresh token" }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/auth/logout
      def logout
        current_user.update(api_token: nil, api_token_digest: nil, api_token_expires_at: nil)
        head :no_content
      end

      # POST /api/v1/auth/cli_token
      # Generate a non-expiring CLI token for AI agents/CLI tools
      def generate_cli_token
        cli_token = current_user.generate_cli_token!
        render json: {
          cli_token: cli_token,
          generated_at: current_user.cli_token_generated_at.iso8601,
          note: "This token does not expire. Keep it secure."
        }, status: :ok
      rescue User::UnconfirmedUserError
        render json: { error: "Account must be confirmed to generate CLI tokens" }, status: :forbidden
      end

      # DELETE /api/v1/auth/cli_token
      # Revoke the CLI token
      def revoke_cli_token
        if current_user.cli_token_digest.present?
          current_user.revoke_cli_token!
          render json: { message: "CLI token revoked successfully" }, status: :ok
        else
          render json: { error: "No CLI token exists" }, status: :not_found
        end
      end

      # GET /api/v1/auth/cli_token/status
      # Check if CLI token exists
      def cli_token_status
        if current_user.cli_token_digest.present?
          render json: {
            exists: true,
            generated_at: current_user.cli_token_generated_at&.iso8601
          }, status: :ok
        else
          render json: { exists: false }, status: :ok
        end
      end
    end
  end
end
