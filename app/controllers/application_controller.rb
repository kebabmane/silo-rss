# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  around_action :use_current_time_zone

  private
    def use_current_time_zone(&block)
      time_zone = Current.time_zone || Time.zone.name
      Time.use_zone(time_zone, &block)
    end
end
