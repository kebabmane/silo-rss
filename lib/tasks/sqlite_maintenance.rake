# frozen_string_literal: true

namespace :sqlite do
  desc "Run SQLite maintenance tasks (VACUUM, ANALYZE, REINDEX)"
  task maintenance: :environment do
    unless ActiveRecord::Base.connection.adapter_name == "SQLite"
      puts "This task is only for SQLite databases."
      next
    end

    puts "Starting SQLite maintenance..."

    # Get all database connections
    databases = {
      primary: ActiveRecord::Base.connection,
      cache: nil,
      queue: nil,
      cable: nil
    }

    # Try to get other database connections if they exist
    begin
      if defined?(SolidCache)
        databases[:cache] = SolidCache::Record.connection rescue nil
      end
      if defined?(SolidQueue)
        databases[:queue] = SolidQueue::Record.connection rescue nil
      end
      if defined?(SolidCable)
        databases[:cable] = SolidCable::Record.connection rescue nil
      end
    rescue => e
      puts "Note: Some Solid databases not available: #{e.message}"
    end

    databases.each do |name, conn|
      next unless conn

      db_path = conn.database_configuration_hash[:database] rescue "unknown"
      puts "\nMaintaining #{name} database: #{db_path}"

      begin
        # Get initial size
        initial_size = get_database_size(conn)
        puts "  Initial size: #{initial_size}"

        # Run VACUUM to reclaim space and defragment
        puts "  Running VACUUM..."
        conn.execute("VACUM")
        puts "  VACUUM complete."

        # Run ANALYZE to update statistics for query optimizer
        puts "  Running ANALYZE..."
        conn.execute("ANALYZE")
        puts "  ANALYZE complete."

        # Run REINDEX to rebuild indexes
        puts "  Running REINDEX..."
        conn.execute("REINDEX")
        puts "  REINDEX complete."

        # Get final size
        final_size = get_database_size(conn)
        puts "  Final size: #{final_size}"

        if initial_size > 0
          savings = initial_size - final_size
          savings_pct = (savings.to_f / initial_size * 100).round(2)
          puts "  Space saved: #{savings} bytes (#{savings_pct}%)"
        end

      rescue => e
        puts "  Error maintaining #{name}: #{e.message}"
        Rails.logger.error("SQLite maintenance error for #{name}: #{e.message}")
      end
    end

    puts "\nSQLite maintenance complete!"
  end

  desc "Check SQLite database integrity"
  task integrity_check: :environment do
    unless ActiveRecord::Base.connection.adapter_name == "SQLite"
      puts "This task is only for SQLite databases."
      next
    end

    conn = ActiveRecord::Base.connection

    puts "Running integrity check on primary database..."

    result = conn.execute("PRAGMA integrity_check")

    if result.first["integrity_check"] == "ok"
      puts "✓ Integrity check passed!"
    else
      puts "✗ Integrity check FAILED!"
      puts result.map(&:to_s).join("\n")
      Rails.logger.error("SQLite integrity check failed: #{result.map(&:to_s).join(', ')}")
    end
  end

  desc "Show SQLite database statistics"
  task stats: :environment do
    unless ActiveRecord::Base.connection.adapter_name == "SQLite"
      puts "This task is only for SQLite databases."
      next
    end

    conn = ActiveRecord::Base.connection

    puts "SQLite Database Statistics"
    puts "=" * 50

    # Page size
    page_size = conn.execute("PRAGMA page_size").first["page_size"]
    puts "Page size: #{page_size} bytes"

    # Page count
    page_count = conn.execute("PRAGMA page_count").first["page_count"]
    puts "Page count: #{page_count}"

    # Freelist count
    freelist_count = conn.execute("PRAGMA freelist_count").first["freelist_count"]
    puts "Free pages: #{freelist_count}"

    # Database size
    db_size = page_size * page_count
    free_size = page_size * freelist_count
    puts "Database size: #{ActiveSupport::NumberHelper.number_to_human_size(db_size)}"
    puts "Free space: #{ActiveSupport::NumberHelper.number_to_human_size(free_size)}"

    # Table statistics
    puts "\nTable Statistics:"
    tables = conn.tables
    tables.each do |table|
      count = conn.execute("SELECT COUNT(*) as count FROM #{table}").first["count"]
      puts "  #{table}: #{count} rows"
    end

    # Index statistics
    puts "\nIndex Statistics:"
    indexes = conn.indexes("articles") + conn.indexes("article_states") + conn.indexes("subscriptions")
    indexes.each do |index|
      puts "  #{index.name}: #{index.columns.join(', ')}"
    end
  end

  private

  def get_database_size(conn)
    page_size = conn.execute("PRAGMA page_size").first["page_size"]
    page_count = conn.execute("PRAGMA page_count").first["page_count"]
    page_size * page_count
  rescue
    0
  end
end
