class AddFts5SearchToArticles < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL
      CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(
        title,
        content,
        full_content,
        content_rowid='id',
        tokenize='porter unicode61'
      );
    SQL

    # Populate the FTS table with existing articles
    execute <<-SQL
      INSERT INTO articles_fts(rowid, title, content, full_content)
      SELECT id, COALESCE(title, ''), COALESCE(content, ''), COALESCE(full_content, '')
      FROM articles;
    SQL

    # Create triggers to keep FTS in sync
    execute <<-SQL
      CREATE TRIGGER IF NOT EXISTS articles_fts_insert AFTER INSERT ON articles BEGIN
        INSERT INTO articles_fts(rowid, title, content, full_content)
        VALUES (new.id, COALESCE(new.title, ''), COALESCE(new.content, ''), COALESCE(new.full_content, ''));
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER IF NOT EXISTS articles_fts_update AFTER UPDATE ON articles BEGIN
        DELETE FROM articles_fts WHERE rowid = old.id;
        INSERT INTO articles_fts(rowid, title, content, full_content)
        VALUES (new.id, COALESCE(new.title, ''), COALESCE(new.content, ''), COALESCE(new.full_content, ''));
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER IF NOT EXISTS articles_fts_delete AFTER DELETE ON articles BEGIN
        DELETE FROM articles_fts WHERE rowid = old.id;
      END;
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS articles_fts_delete"
    execute "DROP TRIGGER IF EXISTS articles_fts_update"
    execute "DROP TRIGGER IF EXISTS articles_fts_insert"
    execute "DROP TABLE IF EXISTS articles_fts"
  end
end
