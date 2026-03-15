class LitellmSetting < ApplicationRecord
  # Singleton pattern - only one row should exist
  validates :server_url, presence: true, if: :enabled?
  validates :default_model, presence: true, if: :enabled?
  validates :max_tokens, numericality: { greater_than: 0, allow_nil: true }
  validates :temperature, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2, allow_nil: true }
  validates :timeout, numericality: { greater_than: 0, allow_nil: true }

  # Encrypt API key
  encrypts :api_key, deterministic: false

  validate :singleton_record, on: :create

  # Singleton methods
  def self.instance
    first_or_create! do |setting|
      setting.server_url = ENV.fetch("LITELLM_SERVER_URL", "http://localhost:4000")
      setting.default_model = ENV.fetch("LITELLM_DEFAULT_MODEL", "gpt-3.5-turbo")
      setting.enabled = false
    end
  end

  def self.configured?
    instance.enabled? && instance.server_url.present? && instance.default_model.present?
  end

  # Instance method to check if properly configured
  def configured?
    enabled? && server_url.present? && default_model.present?
  end

  private

  def singleton_record
    if self.class.where.not(id: id).exists?
      errors.add(:base, "LiteLLM configuration is global; modify the existing record instead.")
    end
  end
end
