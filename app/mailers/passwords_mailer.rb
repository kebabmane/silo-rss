class PasswordsMailer < ApplicationMailer
  def reset(user, token = nil)
    @user = user
    @token = token || user.generate_password_reset_token!
    mail subject: "Reset your password", to: user.email_address
  end
end
