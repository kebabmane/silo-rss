# Ensure FTS5 virtual tables exist after schema load.
# schema.rb cannot represent virtual tables, so we recreate them here
# if they're missing (e.g., after db:test:load_schema).
Rails.application.config.after_initialize do
  next unless ActiveRecord::Base.connection.adapter_name == "SQLite"

  conn = ActiveRecord::Base.connection

  # Check if the FTS table already exists
  tables = conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='articles_fts'")
  next if tables.any?

  # Only create if the articles table exists (skip if DB is empty/not migrated)
  articles_exists = conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='articles'")
  next unless articles_exists.any?

  conn.execute <<-SQL
    CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(
      title, content, full_content,
      content_rowid='id',
      tokenize='porter unicode61'
    );
  SQL

  conn.execute <<-SQL
    INSERT INTO articles_fts(rowid, title, content, full_content)
    SELECT id, COALESCE(title, ''), COALESCE(content, ''), COALESCE(full_content, '')
    FROM articles;
  SQL

  conn.execute <<-SQL
    CREATE TRIGGER IF NOT EXISTS articles_fts_insert AFTER INSERT ON articles BEGIN
      INSERT INTO articles_fts(rowid, title, content, full_content)
      VALUES (new.id, COALESCE(new.title, ''), COALESCE(new.content, ''), COALESCE(new.full_content, ''));
    END;
  SQL

  conn.execute <<-SQL
    CREATE TRIGGER IF NOT EXISTS articles_fts_update AFTER UPDATE ON articles BEGIN
      DELETE FROM articles_fts WHERE rowid = old.id;
      INSERT INTO articles_fts(rowid, title, content, full_content)
      VALUES (new.id, COALESCE(new.title, ''), COALESCE(new.content, ''), COALESCE(new.full_content, ''));
    END;
  SQL

  conn.execute <<-SQL
    CREATE TRIGGER IF NOT EXISTS articles_fts_delete AFTER DELETE ON articles BEGIN
      DELETE FROM articles_fts WHERE rowid = old.id;
    END;
  SQL
end
