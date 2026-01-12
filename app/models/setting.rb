class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  class << self
    def get(key, default = nil)
      find_by(key: key)&.value || default
    end

    def set(key, value)
      setting = find_or_initialize_by(key: key)
      string_value = value.to_s
      setting.value = string_value
      setting.save!
      string_value
    end

    def require_admin_confirmation?
      get("require_admin_confirmation", "false") == "true"
    end

    def require_admin_confirmation=(value)
      bool_value = ActiveModel::Type::Boolean.new.cast(value)
      string_value = bool_value ? "true" : "false"
      set("require_admin_confirmation", string_value)
    end
  end

  def self.require_admin_confirmation
    require_admin_confirmation?
  end

  def self.push_notifications_enabled?
    get("push_notifications_enabled", "false") == "true"
  end

  def self.push_notifications_enabled=(value)
    # Convert boolean to string "true" or "false"
    string_value = value ? "true" : "false"
    set("push_notifications_enabled", string_value)
  end

  def self.push_notifications_enabled
    push_notifications_enabled?
  end
end
