class Current < ActiveSupport::CurrentAttributes
  attribute :session, :time_zone
  delegate :user, to: :session, allow_nil: true
end
