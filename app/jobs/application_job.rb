class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked, wait: :exponentially_longer, attempts: 3

  # Retry network errors with exponential backoff
  retry_on SocketError, wait: :exponentially_longer, attempts: 3
  retry_on Errno::ECONNREFUSED, wait: :exponentially_longer, attempts: 3
  retry_on Timeout::Error, wait: :exponentially_longer, attempts: 3

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError
end
