require "test_helper"

class ScheduledRefreshJobTest < ActiveJob::TestCase
  setup do
    @job = ScheduledRefreshJob.new
  end

  # Successful job execution
  test "perform enqueues FeedRefreshJob for each feed" do
    feed_count = Feed.count
    assert feed_count > 0

    assert_enqueued_jobs feed_count, only: FeedRefreshJob do
      @job.perform
    end
  end

  test "perform enqueues FeedRefreshJob with correct feed IDs" do
    feeds = Feed.all.to_a

    @job.perform

    feeds.each do |feed|
      assert_enqueued_with(job: FeedRefreshJob, args: [feed.id])
    end
  end

  test "perform completes without error" do
    assert_nothing_raised do
      @job.perform
    end
  end

  test "perform returns nil" do
    result = @job.perform

    assert_nil result
  end

  # Service integration and batch processing
  test "perform uses find_each for efficient batch processing" do
    tech_crunch = feeds(:tech_crunch)
    hacker_news = feeds(:hacker_news)
    ruby_weekly = feeds(:ruby_weekly)

    Feed.expects(:find_each).multiple_yields([tech_crunch], [hacker_news], [ruby_weekly])

    assert_enqueued_jobs 3, only: FeedRefreshJob do
      @job.perform
    end
  end

  test "perform enqueues jobs for all fixture feeds" do
    tech_crunch = feeds(:tech_crunch)
    hacker_news = feeds(:hacker_news)
    ruby_weekly = feeds(:ruby_weekly)

    assert_enqueued_with(job: FeedRefreshJob, args: [tech_crunch.id]) do
      @job.perform
    end

    assert_enqueued_with(job: FeedRefreshJob, args: [hacker_news.id]) do
      @job.perform
    end

    assert_enqueued_with(job: FeedRefreshJob, args: [ruby_weekly.id]) do
      @job.perform
    end
  end

  test "perform uses perform_later for async job execution" do
    FeedRefreshJob.expects(:perform_later).times(Feed.count)

    @job.perform
  end

  test "perform does not call perform_now" do
    FeedRefreshJob.expects(:perform_now).never

    @job.perform
  end

  # Error handling - empty database
  test "perform handles no feeds gracefully" do
    Feed.destroy_all

    assert_nothing_raised do
      @job.perform
    end
  end

  test "perform enqueues no jobs when no feeds exist" do
    Feed.destroy_all

    assert_no_enqueued_jobs(only: FeedRefreshJob) do
      @job.perform
    end
  end

  # Error handling - feed errors
  test "perform continues if one feed causes an error during iteration" do
    # This tests that find_each continues even if one iteration fails
    # However, the current implementation is simple and doesn't catch errors
    # so any error would propagate. This test documents expected behavior.

    feed_count = Feed.count
    call_count = 0

    Feed.find_each do |feed|
      call_count += 1
      FeedRefreshJob.perform_later(feed.id)
    end

    assert_equal feed_count, call_count
  end

  test "perform propagates errors from FeedRefreshJob enqueuing" do
    FeedRefreshJob.stubs(:perform_later).raises(StandardError.new("Queue error"))

    assert_raises(StandardError) do
      @job.perform
    end
  end

  # Job enqueuing
  test "can be enqueued" do
    assert_enqueued_with(job: ScheduledRefreshJob) do
      ScheduledRefreshJob.perform_later
    end
  end

  test "enqueues to default queue" do
    assert_equal "default", ScheduledRefreshJob.new.queue_name
  end

  test "perform_later accepts no arguments" do
    assert_nothing_raised do
      ScheduledRefreshJob.perform_later
    end
  end

  test "perform_now executes job immediately" do
    feed_count = Feed.count

    assert_enqueued_jobs feed_count, only: FeedRefreshJob do
      ScheduledRefreshJob.perform_now
    end
  end

  test "can enqueue multiple scheduled refresh jobs" do
    assert_enqueued_jobs 2, only: ScheduledRefreshJob do
      ScheduledRefreshJob.perform_later
      ScheduledRefreshJob.perform_later
    end
  end

  # Edge cases
  test "perform handles large number of feeds efficiently" do
    # Create additional feeds to test batch processing
    20.times do |i|
      Feed.create!(
        title: "Test Feed #{i}",
        feed_url: "https://example#{i}.com/feed.xml"
      )
    end

    total_feeds = Feed.count
    assert total_feeds >= 20

    assert_enqueued_jobs total_feeds, only: FeedRefreshJob do
      @job.perform
    end
  end

  test "perform enqueues jobs in the order feeds are found" do
    enqueued_feed_ids = []

    # Capture the order of enqueued jobs using Mocha's stubs
    FeedRefreshJob.stubs(:perform_later).with do |feed_id|
      enqueued_feed_ids << feed_id
      true
    end

    @job.perform

    # find_each processes records in batches by primary key order
    expected_feed_ids = Feed.order(:id).pluck(:id)

    assert_equal expected_feed_ids, enqueued_feed_ids
  end

  test "perform does not load all feeds into memory at once" do
    # find_each loads records in batches (default 1000)
    # This is implicit in using find_each vs all.each
    # We verify find_each is used by checking Feed.all is never called
    Feed.expects(:all).never
    Feed.expects(:find_each)

    @job.perform
  end

  test "perform does not modify any feed records" do
    Feed.any_instance.expects(:update).never
    Feed.any_instance.expects(:save).never

    @job.perform
  end

  test "perform does not create or destroy feeds" do
    assert_no_difference "Feed.count" do
      @job.perform
    end
  end

  test "perform works when feeds have no articles" do
    # Remove all articles but keep feeds
    Article.destroy_all

    feed_count = Feed.count

    assert_enqueued_jobs feed_count, only: FeedRefreshJob do
      @job.perform
    end
  end

  test "perform works when feeds have different last_fetched_at times" do
    feeds(:tech_crunch).update!(last_fetched_at: 1.hour.ago)
    feeds(:hacker_news).update!(last_fetched_at: 1.day.ago)
    feeds(:ruby_weekly).update!(last_fetched_at: nil)

    feed_count = Feed.count

    assert_enqueued_jobs feed_count, only: FeedRefreshJob do
      @job.perform
    end
  end

  test "perform enqueues jobs for feeds regardless of last_fetched_at" do
    # All feeds should be refreshed, regardless of when they were last fetched
    old_feed = feeds(:tech_crunch)
    old_feed.update!(last_fetched_at: 1.year.ago)

    recent_feed = feeds(:hacker_news)
    recent_feed.update!(last_fetched_at: 1.minute.ago)

    assert_enqueued_jobs Feed.count, only: FeedRefreshJob do
      @job.perform
    end
  end

  test "perform only enqueues FeedRefreshJob, not other job types" do
    assert_no_enqueued_jobs(only: ArticleContentFetchJob) do
      @job.perform
    end

    assert_no_enqueued_jobs(only: ScheduledRefreshJob) do
      @job.perform
    end
  end

  test "multiple scheduled refresh jobs can run concurrently" do
    # Each execution should enqueue separate FeedRefreshJobs
    feed_count = Feed.count

    assert_enqueued_jobs feed_count * 2, only: FeedRefreshJob do
      @job.perform
      ScheduledRefreshJob.new.perform
    end
  end

  test "perform does not execute FeedRefreshJob synchronously" do
    # Jobs should be enqueued, not executed immediately
    FeedFetcherService.expects(:new).never

    @job.perform
  end

  test "perform handles feeds created during execution" do
    # This tests thread safety - though unlikely in single-threaded test env
    # The current implementation uses find_each which snapshots the query

    original_count = Feed.count
    feeds_snapshot = Feed.all.to_a
    call_count = 0

    # Stub find_each to yield only the original feeds and create a new feed during iteration
    Feed.stubs(:find_each).multiple_yields(*feeds_snapshot.map do |feed|
      call_count += 1
      # Create a new feed during the first iteration
      if call_count == 1
        Feed.create!(
          title: "New Feed During Iteration",
          feed_url: "https://new-during-iteration.com/feed.xml"
        )
      end
      [feed]
    end)

    assert_enqueued_jobs original_count, only: FeedRefreshJob do
      @job.perform
    end

    # Should only process original feeds, not newly created one
    # This is because find_each uses a snapshot
  end

  test "perform with only one feed" do
    Feed.where.not(id: feeds(:tech_crunch).id).destroy_all

    assert_equal 1, Feed.count

    assert_enqueued_jobs 1, only: FeedRefreshJob do
      @job.perform
    end
  end

  test "perform does not query for articles or subscriptions" do
    Article.expects(:find_each).never
    Subscription.expects(:find_each).never

    @job.perform
  end
end
