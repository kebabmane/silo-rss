class Admin::SettingsController < ApplicationController
  before_action :ensure_admin!

  def show
    @require_admin_confirmation = Setting.require_admin_confirmation?
  end

  def update
    require_admin_confirmation = params[:require_admin_confirmation] == "1"
    Setting.require_admin_confirmation = require_admin_confirmation

    redirect_to admin_settings_path, notice: "Settings updated successfully."
  end

  private

  def ensure_admin!
    redirect_to dashboard_path, alert: "Access denied." unless Current.user&.admin?
  end
end
