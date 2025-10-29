class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      token = user.generate_password_reset_token!
      PasswordsMailer.reset(user, token).deliver_later
    end

    redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists)."
  end

  def edit
  end

  def update
    # Check if password parameters are missing (nil) or explicitly not provided
    if params[:password].nil? || params[:password_confirmation].nil?
      redirect_to edit_password_path(params[:token]), alert: "Password and confirmation are required."
      return
    end

    if @user.update(params.permit(:password, :password_confirmation))
      @user.clear_password_reset_token!
      redirect_to new_session_path, notice: "Password has been reset."
    else
      redirect_to edit_password_path(params[:token]), alert: "Passwords did not match."
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
    end
end
