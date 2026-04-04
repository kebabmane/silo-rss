class FixFts5TriggerQuotes < ActiveRecord::Migration[8.0]
  def up
    # Drop existing triggers if they exist
    execute "DROP TRIGGER IF EXISTS articles_fts_insert"
    execute "DROP TRIGGER IF EXISTS articles_fts_update"

    # Recreate triggers with correct single quotes for string literals
    execute <<-SQL
      CREATE TRIGGER articles_fts_insert AFTER INSERT ON articles BEGIN
        INSERT INTO articles_fts(rowid, title, content, full_content)
        VALUES (new.id, COALESCE(new.title, ''), COALESCE(new.content, ''), COALESCE(new.full_content, ''));
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER articles_fts_update AFTER UPDATE ON articles BEGIN
        DELETE FROM articles_fts WHERE rowid = old.id;
        INSERT INTO articles_fts(rowid, title, content, full_content)
        VALUES (new.id, COALESCE(new.title, ''), COALESCE(new.content, ''), COALESCE(new.full_content, ''));
      END;
    SQL

    # Also fix the delete trigger if it exists
    execute "DROP TRIGGER IF EXISTS articles_fts_delete"
    execute <<-SQL
      CREATE TRIGGER articles_fts_delete AFTER DELETE ON articles BEGIN
        DELETE FROM articles_fts WHERE rowid = old.id;
      END;
    SQL
  end

  def down
    # Restore the buggy triggers (for rollback purposes)
    execute "DROP TRIGGER IF EXISTS articles_fts_insert"
    execute "DROP TRIGGER IF EXISTS articles_fts_update"
    execute "DROP TRIGGER IF EXISTS articles_fts_delete"

    execute <<-SQL
      CREATE TRIGGER articles_fts_insert AFTER INSERT ON articles BEGIN
        INSERT INTO articles_fts(rowid, title, content, full_content)
        VALUES (new.id, COALESCE(new.title, ""), COALESCE(new.content, ""), COALESCE(new.full_content, ""));
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER articles_fts_update AFTER UPDATE ON articles BEGIN
        DELETE FROM articles_fts WHERE rowid = old.id;
        INSERT INTO articles_fts(rowid, title, content, full_content)
        VALUES (new.id, COALESCE(new.title, ""), COALESCE(new.content, ""), COALESCE(new.full_content, ""));
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER articles_fts_delete AFTER DELETE ON articles BEGIN
        DELETE FROM articles_fts WHERE rowid = old.id;
      END;
    SQL
  end
end
