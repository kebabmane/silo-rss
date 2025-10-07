class DailyBrief < ApplicationRecord
  belongs_to :user
  belongs_to :daily_brief_schedule

  validates :content, presence: true
  validates :generated_at, presence: true

  # Scopes
  scope :recent, -> { order(generated_at: :desc) }
  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :emailed, -> { where.not(emailed_at: nil) }

  # Mark as read
  def mark_as_read!
    update(read: true)
  end

  # Mark as unread
  def mark_as_unread!
    update(read: false)
  end

  # Check if emailed
  def emailed?
    emailed_at.present?
  end
end
