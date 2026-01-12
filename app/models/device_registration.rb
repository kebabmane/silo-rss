class DeviceRegistration < ApplicationRecord
  belongs_to :user

  validates :device_token, presence: true, uniqueness: { scope: :user_id }
  validates :platform, presence: true, inclusion: { in: %w[ios android], message: "%{value} is not a valid platform" }

  # Create or update corresponding ApplicationPushDevice when enabled
  after_save :sync_to_push_device, if: :should_sync_push_device?
  after_destroy :destroy_push_device, if: :push_notifications_enabled?

  private

  def push_notifications_enabled?
    Setting.push_notifications_enabled?
  end

  def should_sync_push_device?
    push_notifications_enabled? && device_token.present?
  end

  def sync_to_push_device
    return unless defined?(ApplicationPushDevice)

    ApplicationPushDevice.find_or_initialize_by(
      token: device_token,
      platform: platform == "ios" ? "apple" : "google"
    ).tap do |device|
      device.owner = user
      device.save!
    end
  end

  def destroy_push_device
    return unless defined?(ApplicationPushDevice)

    ApplicationPushDevice.where(token: device_token).destroy_all
  end
end
