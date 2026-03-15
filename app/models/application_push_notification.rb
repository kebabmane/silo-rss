class ApplicationPushNotification < ActionPushNative::Notification
  # Only enable push notifications if the server setting is enabled
  # This allows deployments to opt-in to push notifications
  self.enabled = -> { Setting.push_notifications_enabled? && !Rails.env.test? }

  # Set a custom job queue_name
  # queue_as :realtime

  # Define a custom callback to modify or abort the notification before it is sent
  # before_delivery do |notification|
  #   throw :abort if notification.expired?
  # end
end
