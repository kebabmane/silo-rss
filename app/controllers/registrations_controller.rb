class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]

  rescue_from ActionController::ParameterMissing do |e|
    @user = User.new
    render :new, status: :bad_request
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to new_session_path, notice: "Your account has been created and is awaiting admin approval."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
