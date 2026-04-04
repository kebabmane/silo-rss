class Admin::SettingsController < AdminController
  def show
    @require_admin_confirmation = Setting.require_admin_confirmation?
  end

  def update
    if params.key?(:require_admin_confirmation)
      require_admin_confirmation = params[:require_admin_confirmation] == "1"
      Setting.set("require_admin_confirmation", require_admin_confirmation ? "true" : "false")
    end

    redirect_to admin_settings_path, notice: "Settings updated successfully."
  end
end
