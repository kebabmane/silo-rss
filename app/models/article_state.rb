class ArticleState < ApplicationRecord
  belongs_to :user
  belongs_to :article

  validates :user_id, uniqueness: { scope: :article_id }

  scope :unread, -> { where(read: false) }
  scope :starred, -> { where(starred: true) }
  scope :archived, -> { where(archived: true) }
end
