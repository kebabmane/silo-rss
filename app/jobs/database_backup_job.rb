class DatabaseBackupJob < ApplicationJob
  queue_as :default

  def perform
    backup_dir = Rails.root.join("storage", "backups")
    FileUtils.mkdir_p(backup_dir)

    db_path = ActiveRecord::Base.connection_db_config.database
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    backup_path = backup_dir.join("silo_backup_#{timestamp}.sqlite3")

    # Use SQLite's backup API via the VACUUM INTO command.
    # The path is safe — constructed only from Rails.root and Time.current.
    vacuum_sql = "VACUUM INTO '#{ActiveRecord::Base.connection.quote_string(backup_path.to_s)}'"
    ActiveRecord::Base.connection.execute(vacuum_sql) # brakeman:ignore:SQL

    Rails.logger.info("Database backup created at #{backup_path}")

    # Prune old backups — keep only the last 7
    backups = Dir.glob(backup_dir.join("silo_backup_*.sqlite3")).sort
    if backups.size > 7
      backups[0...-7].each do |old_backup|
        File.delete(old_backup)
        Rails.logger.info("Deleted old backup: #{old_backup}")
      end
    end
  rescue => e
    Rails.logger.error("Database backup failed: #{e.message}")
    raise
  end
end
