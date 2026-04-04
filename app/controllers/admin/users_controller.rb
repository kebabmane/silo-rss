module Admin
  class UsersController < AdminController
    before_action :set_user, only: [ :update, :confirm ]

    def index
      @users = User.order(created_at: :desc).includes(:confirmed_by)
    end

    def update
      if @user.update(user_params)
        redirect_to admin_users_path, notice: "User updated successfully."
      else
        redirect_to admin_users_path, alert: @user.errors.full_messages.to_sentence
      end
    end

    def confirm
      if @user.confirmed?
        redirect_to admin_users_path, notice: "User is already confirmed."
      else
        @user.confirm!(confirmed_by: Current.user)
        redirect_to admin_users_path, notice: "User confirmed successfully."
      end
    rescue StandardError => e
      redirect_to admin_users_path, alert: "Failed to confirm user: #{e.message}"
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:admin)
    end
  end
end
