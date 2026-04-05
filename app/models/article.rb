# frozen_string_literal: true

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
  scope :cursor_after, ->(cursor) {
    return all if cursor.blank?

    decoded = Article.decode_cursor(cursor)
    return all if decoded.blank?

    where("published_at < ? OR (published_at = ? AND id < ?)",
          decoded[:published_at], decoded[:published_at], decoded[:id])
  }
  scope :sync_since, ->(timestamp) {
    return all if timestamp.blank?

    where("articles.updated_at > ?", timestamp)
  }

  CURSOR_SEPARATOR = "_"

  def self.encode_cursor(article)
    return nil unless article

    Base64.urlsafe_encode64("#{article.published_at.iso8601}#{CURSOR_SEPARATOR}#{article.id}")
  end

  def self.decode_cursor(cursor)
    return nil if cursor.blank?

    decoded = Base64.urlsafe_decode64(cursor)
    parts = decoded.split(CURSOR_SEPARATOR, 2)
    return nil unless parts.size == 2

    {
      published_at: Time.iso8601(parts[0]),
      id: parts[1].to_i
    }
  rescue ArgumentError, StandardError
    nil
  end

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

  # Calculate estimated reading time
  def reading_time
    word_count = display_content.to_s.gsub(/<[^>]+>/, "").split.size
    minutes = (word_count / 200.0).ceil
    minutes < 1 ? "< 1 min" : "#{minutes} min"
  end
end
