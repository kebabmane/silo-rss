class DailyBriefSchedule < ApplicationRecord
  belongs_to :user
  has_many :feed_filters, class_name: "DailyBriefFeedFilter", dependent: :destroy
  has_many :filtered_feeds, through: :feed_filters, source: :feed
  has_many :daily_briefs, dependent: :destroy

  validates :time_of_day, presence: true
  validates :summary_length, inclusion: { in: %w[short medium detailed] }
  validate :days_of_week_format

  # Scopes
  scope :active, -> { where(active: true) }

  # Check if this schedule should run on a given date
  def should_run_on?(date)
    return false unless active?
    return true if days_of_week.empty? # Run every day if no specific days set

    day_name = date.strftime("%A").downcase
    days_of_week.map(&:downcase).include?(day_name)
  end

  # Get feeds to include in the brief
  def feeds_to_include
    if include_all_feeds?
      user.feeds
    else
      filtered_feeds
    end
  end

  # Check if it's time to generate a brief (within the current hour)
  def time_to_generate?(current_time = Time.current)
    return false unless should_run_on?(current_time.to_date)

    schedule_hour = time_of_day.hour
    schedule_minute = time_of_day.min

    current_time.hour == schedule_hour && current_time.min >= schedule_minute
  end

  private

  def days_of_week_format
    return if days_of_week.blank?

    unless days_of_week.is_a?(Array)
      errors.add(:days_of_week, "must be an array")
      return
    end

    valid_days = %w[monday tuesday wednesday thursday friday saturday sunday]
    invalid_days = days_of_week.reject { |day| valid_days.include?(day.to_s.downcase) }

    if invalid_days.any?
      errors.add(:days_of_week, "contains invalid day(s): #{invalid_days.join(', ')}")
    end
  end
end
