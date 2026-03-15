class Admin::SettingsController < AdminController
  def show
    @require_admin_confirmation = Setting.require_admin_confirmation?
    @push_notifications_enabled = Setting.push_notifications_enabled?
  end

  def update
    if params.key?(:require_admin_confirmation)
      require_admin_confirmation = params[:require_admin_confirmation] == "1"
      Setting.set("require_admin_confirmation", require_admin_confirmation ? "true" : "false")
    end

    if params.key?(:push_notifications_enabled)
      push_notifications_enabled = params[:push_notifications_enabled] == "1"
      Setting.set("push_notifications_enabled", push_notifications_enabled ? "true" : "false")
    end

    redirect_to admin_settings_path, notice: "Settings updated successfully."
  end
end
