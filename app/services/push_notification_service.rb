# Push notification service using Action Push Native
# This service is only active when push_notifications_enabled setting is true
class PushNotificationService
  class << self
    def daily_brief_generated(user, brief)
      return unless Setting.push_notifications_enabled?
      return if user.device_registrations.empty?

      # Get all registered devices for this user
      devices = user.device_registrations.map do |registration|
        # Find or reference the ApplicationPushDevice for this registration
        ApplicationPushDevice.find_by(token: registration.device_token, platform: map_platform(registration.platform))
      end.compact

      return if devices.empty?

      # Create and send the notification asynchronously
      notification = DailyBriefPushNotification.new(user, brief)
      notification.deliver_later_to(devices)
    rescue => e
      Rails.logger.error("Failed to send daily brief push notification: #{e.message}")
    end

    private

    # Map our platform names to Action Push Native platform names
    def map_platform(registration_platform)
      case registration_platform
      when "ios"
        "apple"
      when "android"
        "google"
      else
        registration_platform
      end
    end
  end
end
