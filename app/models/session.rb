class Session < ApplicationRecord
  belongs_to :user

  before_create :set_expiry

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  private

  def set_expiry
    self.expires_at = 90.days.from_now
  end
end
