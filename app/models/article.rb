class Article < ApplicationRecord
  belongs_to :feed, counter_cache: true
  has_many :article_states, dependent: :destroy

  validates :guid, presence: true, uniqueness: { scope: :feed_id }

  scope :recent, -> { order(published_at: :desc) }
  scope :needs_content_fetch, -> { where(full_content: nil).where("LENGTH(content) < 500 OR content IS NULL") }
  scope :for_user, ->(user) {
    joins(feed: :subscriptions).where(subscriptions: { user_id: user.id })
  }
  scope :unread_for, ->(user) {
    left_joins(:article_states)
      .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.read = ?)", user.id, false)
      .where("article_states.id IS NULL OR article_states.archived = ?", false)
  }
  scope :starred_for, ->(user) {
    joins(:article_states).where(article_states: { user_id: user.id, starred: true })
  }
  scope :archived_for, ->(user) {
    joins(:article_states).where(article_states: { user_id: user.id, archived: true })
  }
  scope :all_unarchived_for, ->(user) {
    left_joins(:article_states)
      .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.archived = ?)", user.id, false)
  }
  scope :search_text, ->(query) {
    if fts5_available?
      sanitized = query.to_s.gsub('"', '""')
      where("articles.id IN (SELECT rowid FROM articles_fts WHERE articles_fts MATCH ?)", "\"#{sanitized}\"")
    else
      sanitized = query.to_s.gsub(/[\\%_]/) { |x| "\\#{x}" }
      where("articles.title LIKE ? OR articles.content LIKE ? OR articles.full_content LIKE ?",
            "%#{sanitized}%", "%#{sanitized}%", "%#{sanitized}%")
    end
  }

  def self.fts5_available?
    return @fts5_available if defined?(@fts5_available)

    @fts5_available = begin
      connection.execute("SELECT * FROM articles_fts LIMIT 0")
      true
    rescue ActiveRecord::StatementInvalid
      false
    end
  end

  # Get or create article state for a user
  def state_for(user)
    # Try to use preloaded state first
    if association(:article_states).loaded?
      article_states.detect { |s| s.user_id == user.id } || article_states.create(user: user)
    else
      article_states.find_or_create_by(user: user)
    end
  end

  # Get the best available content (prefer full_content, fallback to RSS content)
  def display_content
    full_content.presence || content
  end

  # Check if full content has been fetched
  def full_content_fetched?
    full_content.present?
  end

  # Check if this article needs content fetching
  def needs_content_fetch?
    ArticleContentFetcherService.needs_fetch?(self)
  end
end
