module ApiAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_user
  end

  private

  def authenticate_api_user
    token = request.headers['Authorization']&.gsub('Bearer ', '')

    if token.present?
      @current_user = User.find_by_api_token(token)

      if @current_user&.api_token_expired?
        render json: { error: 'Token expired. Please refresh your token.' }, status: :unauthorized
        return
      end
    end

    unless @current_user
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end
end
