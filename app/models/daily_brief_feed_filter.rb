class DailyBriefFeedFilter < ApplicationRecord
  belongs_to :daily_brief_schedule
  belongs_to :feed

  validates :feed_id, uniqueness: { scope: :daily_brief_schedule_id }
end
