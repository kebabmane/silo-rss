module ApiAuthentication
  extend ActiveSupport::Concern

  included do
    skip_before_action :require_authentication, raise: false
    before_action :authenticate_api_user
  end

  private

  def authenticate_api_user
    auth_header = request.headers["Authorization"]
    token = extract_token(auth_header)

    if token.present?
      # Try API token first (may be expired)
      @current_user = User.find_by_api_token(token)

      if @current_user&.api_token_expired?
        render json: { error: "Token expired. Please refresh your token." }, status: :unauthorized
        return
      end

      # Try CLI token (never expires)
      unless @current_user
        @current_user = User.find_by_cli_token(token)
      end
    end

    unless @current_user
      render json: { error: "Unauthorized" }, status: :unauthorized
      nil
    end
  end

  def extract_token(auth_header)
    return nil if auth_header.blank?

    # Support both "Bearer token" and plain "token" formats
    if auth_header.start_with?("Bearer ")
      auth_header[7..-1] # Remove "Bearer " prefix (7 characters)
    else
      auth_header
    end
  end

  def current_user
    @current_user
  end
end
