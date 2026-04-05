# frozen_string_literal: true

class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." } unless Rails.env.test?
  rate_limit to: 5, within: 20.seconds, by: -> { params[:email_address] }, only: :create, with: -> { redirect_to new_session_url, alert: "Too many login attempts. Try again shortly." } unless Rails.env.test?

  def new
  end

  def create
    credentials = params.permit(:email_address, :password)

    if credentials[:email_address].blank? || credentials[:password].blank?
      redirect_to new_session_path, alert: "Try another email address or password."
      return
    end

    user = User.authenticate_by(credentials)

    if user
      # Check if admin confirmation is required
      if Setting.require_admin_confirmation? && !user.confirmed?
        redirect_to new_session_path, alert: "Your account is awaiting admin approval."
      else
        start_new_session_for user
        redirect_to after_authentication_url
      end
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
end
