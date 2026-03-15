class DailyBrief < ApplicationRecord
  belongs_to :user
  belongs_to :daily_brief_schedule

  DIGEST_TYPES = %w[brief digest].freeze

  validates :content, presence: true
  validates :generated_at, presence: true
  validates :digest_type, inclusion: { in: DIGEST_TYPES }, allow_nil: true

  # Scopes
  scope :recent, -> { order(generated_at: :desc) }
  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :emailed, -> { where.not(emailed_at: nil) }
  scope :briefs, -> { where(digest_type: "brief") }
  scope :digests, -> { where(digest_type: "digest") }

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

  # Digest type helpers
  def digest?
    digest_type == "digest"
  end

  def brief?
    digest_type != "digest"
  end

  # Reading time - calculate if not stored
  def reading_time
    reading_time_minutes || calculate_reading_time
  end

  # Ensure sections returns array
  def sections
    self[:sections] || []
  end

  # Ensure themes returns array
  def themes
    self[:themes] || []
  end

  # Ensure article_ids returns array
  def article_ids
    self[:article_ids] || []
  end

  # Get associated articles
  def articles
    return Article.none if article_ids.blank?
    Article.where(id: article_ids)
  end

  private

  def calculate_reading_time
    return 0 if content.blank?
    words = content.split.size
    (words / 200.0).ceil # ~200 words per minute
  end
end
