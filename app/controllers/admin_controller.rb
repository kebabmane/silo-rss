class AdminController < ApplicationController
  before_action :require_admin!

  private

  def require_admin!
    return if Current.user&.admin?

    respond_to do |format|
      format.html do
        redirect_to dashboard_path, alert: "You are not authorized to access that area."
        return
      end

      format.json do
        render json: { error: "Forbidden" }, status: :forbidden
        return
      end

      format.any do
        head :forbidden
        return
      end
    end
  end
end
