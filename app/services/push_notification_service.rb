require "net/http"
class PushNotificationService
  FCM_ENDPOINT = URI("https://fcm.googleapis.com/fcm/send").freeze

  class << self
    def daily_brief_generated(user, brief)
      tokens = user.device_registrations.pluck(:device_token)
      return if tokens.empty?

      title = "New daily brief ready"
      body = "Your summary for #{brief.generated_at.in_time_zone(user.time_zone_or_default).strftime('%B %d')} is available."

      payload = {
        registration_ids: tokens,
        priority: "high",
        notification: {
          title: title,
          body: body
        },
        data: {
          type: "daily_brief",
          brief_id: brief.id
        }
      }

      post_to_fcm(payload)
    end

    private

    def post_to_fcm(payload)
      server_key = ENV["FCM_SERVER_KEY"]
      unless server_key.present?
        Rails.logger.info("FCM_SERVER_KEY not configured; skipping push notification")
        return
      end

      http = Net::HTTP.new(FCM_ENDPOINT.host, FCM_ENDPOINT.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(FCM_ENDPOINT)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "key=#{server_key}"
      request.body = payload.to_json

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("FCM push failed: #{response.code} #{response.body}")
      end
    rescue => e
      Rails.logger.error("FCM push error: #{e.message}")
    end
  end
end
