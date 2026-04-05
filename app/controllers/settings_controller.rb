# frozen_string_literal: true

class SettingsController < ApplicationController
  def show
    @user = Current.user
    @time_zone_options = User::TIME_ZONE_OPTIONS
  end

  def update
    @user = Current.user
    if @user.update(settings_params)
      Current.time_zone = @user.time_zone_or_default
      redirect_to settings_path, notice: "Settings updated successfully."
    else
      @time_zone_options = User::TIME_ZONE_OPTIONS
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:user).permit(:time_zone)
  end
end
