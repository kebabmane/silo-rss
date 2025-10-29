module Admin
  class LitellmSettingsController < AdminController
    def show
      @setting = LitellmSetting.instance
      @models = fetch_available_models
    end

    def update
      @setting = LitellmSetting.instance

      if @setting.update(setting_params)
        Rails.logger.info "LiteLLM settings updated successfully."
        redirect_to admin_litellm_settings_path, notice: "LiteLLM settings updated successfully."
      else
        Rails.logger.error "Failed to update LiteLLM settings: #{@setting.errors.full_messages.to_sentence}"
        @models = fetch_available_models
        render :show, status: :unprocessable_entity
      end
    end

    def test_connection
      begin
        client = LitellmClientService.new
        if client.test_connection
          redirect_to admin_litellm_settings_path, notice: "Connection successful!"
        else
          redirect_to admin_litellm_settings_path, alert: "Connection failed."
        end
      rescue LitellmClientService::Error, Errno::ECONNREFUSED, SocketError, Timeout::Error => e
        redirect_to admin_litellm_settings_path, alert: "Connection failed: #{e.message}"
      end
    end

    def fetch_models
      @setting = LitellmSetting.instance

      begin
        client = LitellmClientService.new
        @models = client.list_models
        flash.now[:notice] = "Fetched #{@models.count} models from LiteLLM server"
      rescue LitellmClientService::Error, Errno::ECONNREFUSED, SocketError, Timeout::Error => e
        @models = []
        flash.now[:alert] = "Failed to fetch models: #{e.message}"
      end

      render :show
    end

    private

    def setting_params
      permitted = params.require(:litellm_setting).permit(
        :server_url,
        :api_key,
        :default_model,
        :max_tokens,
        :temperature,
        :timeout,
        :enabled
      )

      # Don't update api_key if it's blank (to preserve existing value)
      permitted.delete(:api_key) if permitted[:api_key].blank?

      permitted
    end

    def fetch_available_models
      return [] unless LitellmSetting.instance.configured?

      begin
        client = LitellmClientService.new
        client.list_models
      rescue LitellmClientService::Error, Errno::ECONNREFUSED, SocketError, Timeout::Error => e
        Rails.logger.warn("Failed to fetch models: #{e.message}")
        []
      end
    end
  end
end
