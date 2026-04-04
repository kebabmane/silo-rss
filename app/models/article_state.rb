class ArticleState < ApplicationRecord
  belongs_to :user
  belongs_to :article

  validates :user_id, uniqueness: { scope: :article_id }

  scope :unread, -> { where(read: false) }
  scope :starred, -> { where(starred: true) }
  scope :archived, -> { where(archived: true) }

  # Bulk upsert article states for a user.
  # attribute should be :read, :starred, or :archived.
  # article_ids is an array of article IDs to update.
  def self.bulk_set(user:, article_ids:, attribute:, value:)
    return 0 if article_ids.empty?

    now = Time.current
    records = article_ids.map do |article_id|
      {
        user_id: user.id,
        article_id: article_id,
        read: attribute == :read ? value : false,
        starred: attribute == :starred ? value : false,
        archived: attribute == :archived ? value : false,
        created_at: now,
        updated_at: now
      }
    end

    upsert_all(
      records,
      unique_by: %i[user_id article_id],
      update_only: [ attribute, :updated_at ]
    )

    article_ids.size
  end
end
