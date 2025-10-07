class Feed < ApplicationRecord
  has_many :articles, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :users, through: :subscriptions

  validates :feed_url, presence: true, uniqueness: true
  validates :title, presence: true
end
