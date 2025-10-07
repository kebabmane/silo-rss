require "digest"
require "openssl"
require "active_support/security_utils"

class User < ApplicationRecord
  class UnconfirmedUserError < StandardError; end

  PASSWORD_MIN_LENGTH = 8
  PASSWORD_RESET_TOKEN_TTL = 15.minutes
  PASSWORD_RESET_TOKEN_LENGTH = 24
  TOKEN_EXPIRATION_TIME = 90.days
  TOKEN_HMAC_KEY = "api-token"

  belongs_to :confirmed_by, class_name: "User", optional: true

  has_secure_password
  encrypts :api_token, deterministic: false

  has_many :sessions, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :feeds, through: :subscriptions
  has_many :article_states, dependent: :destroy
  has_many :daily_brief_schedules, dependent: :destroy
  has_many :daily_briefs, dependent: :destroy

  validates :email_address, presence: true, uniqueness: true
  validates :password,
            presence: true,
            confirmation: true,
            length: { minimum: PASSWORD_MIN_LENGTH, maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED },
            if: :password_attribute_assigned?

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  attribute :theme, :string, default: "light"

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :pending_confirmation, -> { where(confirmed_at: nil) }

  class << self
    def find_by_password_reset_token!(token)
      user = find_by_password_reset_token(token)
      raise ActiveSupport::MessageVerifier::InvalidSignature if user.nil?

      user
    end

    def find_by_password_reset_token(token)
      return if token.blank?

      digest = password_reset_digest_for(token)
      user = find_by(password_reset_digest: digest)
      return if user&.password_reset_token_expired?

      user
    end

    def password_reset_digest_for(token)
      Digest::SHA256.hexdigest(token)
    end

    def find_by_api_token(token)
      return if token.blank?

      digest = token_digest(token)
      confirmed.find_by(api_token_digest: digest)
    end

    def token_digest(token)
      secret = Rails.application.secret_key_base
      OpenSSL::HMAC.hexdigest("SHA256", secret, "#{TOKEN_HMAC_KEY}:#{token}")
    end
  end

  def generate_token_for(purpose)
    case purpose
    when :password_reset
      generate_password_reset_token!
    else
      raise ArgumentError, "Unsupported token purpose: #{purpose}"
    end
  end

  def generate_password_reset_token!
    loop do
      token = SecureRandom.urlsafe_base64(PASSWORD_RESET_TOKEN_LENGTH)
      digest = self.class.password_reset_digest_for(token)

      begin
        update!(
          password_reset_digest: digest,
          password_reset_sent_at: Time.current
        )
        return token
      rescue ActiveRecord::RecordNotUnique
        next
      end
    end
  end

  def clear_password_reset_token!
    update!(password_reset_digest: nil, password_reset_sent_at: nil)
  end

  def password_reset_token_expired?
    return true if password_reset_sent_at.blank?

    password_reset_sent_at < PASSWORD_RESET_TOKEN_TTL.ago
  end

  def ensure_api_token!
    raise UnconfirmedUserError unless confirmed?

    return self[:api_token] if self[:api_token].present? && !api_token_expired?

    issue_api_token!
  end

  def issue_api_token!
    raise UnconfirmedUserError unless confirmed?

    token = SecureRandom.hex(32)
    digest = self.class.token_digest(token)

    update!(
      api_token: token,
      api_token_digest: digest,
      api_token_expires_at: TOKEN_EXPIRATION_TIME.from_now
    )

    token
  end

  alias regenerate_api_token! issue_api_token!

  def api_token_expired?
    api_token_expires_at.present? && api_token_expires_at < Time.current
  end

  def api_token_valid?
    api_token_digest.present? && !api_token_expired?
  end

  def token_matches?(token)
    return false if api_token_digest.blank? || token.blank? || !confirmed?

    ActiveSupport::SecurityUtils.secure_compare(self.class.token_digest(token), api_token_digest)
  end

  def confirmed?
    confirmed_at.present?
  end

  def confirm!(confirmed_by: nil)
    return if confirmed?

    if confirmed_by.present? && !confirmed_by.admin?
      raise ArgumentError, "confirmed_by must be an admin"
    end

    transaction do
      update!(
        confirmed_at: Time.current,
        confirmed_by: confirmed_by
      )

      token = assign_initial_api_token
      save! if changed?
      token
    end
  end

  private
    def assign_initial_api_token
      return unless confirmed?

      token = SecureRandom.hex(32)
      self.api_token = token
      self.api_token_digest = self.class.token_digest(token)
      self.api_token_expires_at = TOKEN_EXPIRATION_TIME.from_now
      token
    end

    def password_attribute_assigned?
      !@password.nil? || !@password_confirmation.nil?
    end

end
