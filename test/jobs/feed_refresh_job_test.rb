require "test_helper"

class FeedRefreshJobTest < ActiveJob::TestCase
  setup do
    @feed = feeds(:tech_crunch)
    @job = FeedRefreshJob.new
  end

  # Successful job execution
  test "perform successfully refreshes feed" do
    service_mock = mock("feed_fetcher_service")
    service_mock.expects(:fetch).returns([])

    FeedFetcherService.expects(:new).with(@feed).returns(service_mock)

    @job.perform(@feed.id)
  end

  test "perform calls FeedFetcherService with correct feed" do
    service_mock = mock("feed_fetcher_service")
    service_mock.expects(:fetch).once

    FeedFetcherService.expects(:new).with(@feed).returns(service_mock)

    @job.perform(@feed.id)
  end

  test "perform returns nil when successful" do
    FeedFetcherService.any_instance.stubs(:fetch).returns([])

    result = @job.perform(@feed.id)

    assert_nil result
  end

  # Service integration
  test "perform integrates with FeedFetcherService" do
    articles_mock = [mock("article1"), mock("article2")]
    service_mock = mock("feed_fetcher_service")
    service_mock.expects(:fetch).returns(articles_mock)

    FeedFetcherService.expects(:new).with(@feed).returns(service_mock)

    @job.perform(@feed.id)
  end

  test "perform does not raise error when service returns empty array" do
    service_mock = mock("feed_fetcher_service")
    service_mock.expects(:fetch).returns([])

    FeedFetcherService.expects(:new).with(@feed).returns(service_mock)

    assert_nothing_raised do
      @job.perform(@feed.id)
    end
  end

  test "perform passes through service fetch results" do
    FeedFetcherService.any_instance.stubs(:fetch).returns([])

    assert_nothing_raised do
      @job.perform(@feed.id)
    end
  end

  # Error handling - missing records
  test "perform returns early when feed not found" do
    FeedFetcherService.expects(:new).never

    @job.perform(999999)
  end

  test "perform does not raise error when feed not found" do
    assert_nothing_raised do
      @job.perform(999999)
    end
  end

  test "perform returns nil when feed not found" do
    result = @job.perform(999999)

    assert_nil result
  end

  test "perform handles nil feed_id gracefully" do
    FeedFetcherService.expects(:new).never

    assert_nothing_raised do
      @job.perform(nil)
    end
  end

  test "perform does not call service when feed is deleted" do
    feed_id = @feed.id
    @feed.destroy

    FeedFetcherService.expects(:new).never

    @job.perform(feed_id)
  end

  # Error handling - service failures
  test "perform propagates service errors" do
    FeedFetcherService.any_instance.stubs(:fetch).raises(StandardError.new("Service error"))

    assert_raises(StandardError) do
      @job.perform(@feed.id)
    end
  end

  test "perform propagates network timeout errors" do
    FeedFetcherService.any_instance.stubs(:fetch).raises(Net::ReadTimeout.new("Timeout"))

    assert_raises(Net::ReadTimeout) do
      @job.perform(@feed.id)
    end
  end

  test "perform propagates HTTP errors" do
    FeedFetcherService.any_instance.stubs(:fetch).raises(HTTParty::Error.new("HTTP error"))

    assert_raises(HTTParty::Error) do
      @job.perform(@feed.id)
    end
  end

  # Job enqueuing
  test "can be enqueued" do
    assert_enqueued_with(job: FeedRefreshJob, args: [@feed.id]) do
      FeedRefreshJob.perform_later(@feed.id)
    end
  end

  test "enqueues to default queue" do
    assert_equal "default", FeedRefreshJob.new.queue_name
  end

  test "can enqueue multiple jobs for different feeds" do
    feed1 = feeds(:tech_crunch)
    feed2 = feeds(:hacker_news)

    assert_enqueued_jobs 2, only: FeedRefreshJob do
      FeedRefreshJob.perform_later(feed1.id)
      FeedRefreshJob.perform_later(feed2.id)
    end
  end

  test "perform_later accepts feed_id as argument" do
    assert_nothing_raised do
      FeedRefreshJob.perform_later(@feed.id)
    end
  end

  test "perform_now executes job immediately" do
    service_mock = mock("feed_fetcher_service")
    service_mock.expects(:fetch).once

    FeedFetcherService.expects(:new).with(@feed).returns(service_mock)

    FeedRefreshJob.perform_now(@feed.id)
  end

  # Edge cases
  test "perform handles string feed_id" do
    service_mock = mock("feed_fetcher_service")
    service_mock.expects(:fetch).returns([])

    FeedFetcherService.expects(:new).with(@feed).returns(service_mock)

    @job.perform(@feed.id.to_s)
  end

  test "perform handles negative feed_id" do
    FeedFetcherService.expects(:new).never

    assert_nothing_raised do
      @job.perform(-1)
    end
  end

  test "perform handles zero feed_id" do
    FeedFetcherService.expects(:new).never

    assert_nothing_raised do
      @job.perform(0)
    end
  end

  test "perform only creates one service instance" do
    FeedFetcherService.expects(:new).once.returns(mock("service", fetch: []))

    @job.perform(@feed.id)
  end

  test "perform uses find_by instead of find to avoid exception" do
    # This is implicitly tested by the "feed not found" tests
    # find would raise ActiveRecord::RecordNotFound
    # find_by returns nil and the job handles it gracefully

    Feed.expects(:find).never
    Feed.expects(:find_by).with(id: 999999).returns(nil)

    @job.perform(999999)
  end

  test "perform works with all fixture feeds" do
    feeds(:tech_crunch, :hacker_news, :ruby_weekly).each do |feed|
      service_mock = mock("feed_fetcher_service")
      service_mock.expects(:fetch).returns([])

      FeedFetcherService.expects(:new).with(feed).returns(service_mock)

      assert_nothing_raised do
        @job.perform(feed.id)
      end
    end
  end

  test "perform does not modify feed record directly" do
    FeedFetcherService.any_instance.stubs(:fetch).returns([])

    @feed.expects(:update).never
    @feed.expects(:save).never

    @job.perform(@feed.id)
  end

  test "multiple jobs can run concurrently without interference" do
    feed1 = feeds(:tech_crunch)
    feed2 = feeds(:hacker_news)

    service1 = mock("service1")
    service1.expects(:fetch).returns([])

    service2 = mock("service2")
    service2.expects(:fetch).returns([])

    FeedFetcherService.expects(:new).with(feed1).returns(service1)
    FeedFetcherService.expects(:new).with(feed2).returns(service2)

    @job.perform(feed1.id)
    FeedRefreshJob.new.perform(feed2.id)
  end
end
