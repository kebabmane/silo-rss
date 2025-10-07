require "test_helper"

class ArticleContentFetchJobTest < ActiveJob::TestCase
  setup do
    @article = articles(:tc_article_1)
    @job = ArticleContentFetchJob.new
  end

  # Successful job execution
  test "perform successfully fetches article content" do
    service_mock = mock("article_content_fetcher_service")
    service_mock.expects(:fetch).returns(true)

    ArticleContentFetcherService.expects(:new).with(@article).returns(service_mock)

    @job.perform(@article.id)
  end

  test "perform calls ArticleContentFetcherService with correct article" do
    service_mock = mock("article_content_fetcher_service")
    service_mock.expects(:fetch).once

    ArticleContentFetcherService.expects(:new).with(@article).returns(service_mock)

    @job.perform(@article.id)
  end

  test "perform returns nil when successful" do
    ArticleContentFetcherService.any_instance.stubs(:fetch).returns(true)

    result = @job.perform(@article.id)

    assert_nil result
  end

  # Service integration
  test "perform integrates with ArticleContentFetcherService" do
    service_mock = mock("article_content_fetcher_service")
    service_mock.expects(:fetch).returns(true)

    ArticleContentFetcherService.expects(:new).with(@article).returns(service_mock)

    @job.perform(@article.id)
  end

  test "perform does not raise error when service returns false" do
    service_mock = mock("article_content_fetcher_service")
    service_mock.expects(:fetch).returns(false)

    ArticleContentFetcherService.expects(:new).with(@article).returns(service_mock)

    assert_nothing_raised do
      @job.perform(@article.id)
    end
  end

  test "perform does not raise error when service returns nil" do
    service_mock = mock("article_content_fetcher_service")
    service_mock.expects(:fetch).returns(nil)

    ArticleContentFetcherService.expects(:new).with(@article).returns(service_mock)

    assert_nothing_raised do
      @job.perform(@article.id)
    end
  end

  test "perform passes through service fetch results" do
    ArticleContentFetcherService.any_instance.stubs(:fetch).returns(true)

    assert_nothing_raised do
      @job.perform(@article.id)
    end
  end

  # Error handling - missing records
  test "perform returns early when article not found" do
    ArticleContentFetcherService.expects(:new).never

    @job.perform(999999)
  end

  test "perform does not raise error when article not found" do
    assert_nothing_raised do
      @job.perform(999999)
    end
  end

  test "perform returns nil when article not found" do
    result = @job.perform(999999)

    assert_nil result
  end

  test "perform handles nil article_id gracefully" do
    ArticleContentFetcherService.expects(:new).never

    assert_nothing_raised do
      @job.perform(nil)
    end
  end

  test "perform does not call service when article is deleted" do
    article_id = @article.id
    @article.destroy

    ArticleContentFetcherService.expects(:new).never

    @job.perform(article_id)
  end

  # Error handling - service failures
  test "perform propagates service errors" do
    ArticleContentFetcherService.any_instance.stubs(:fetch).raises(StandardError.new("Service error"))

    assert_raises(StandardError) do
      @job.perform(@article.id)
    end
  end

  test "perform propagates network timeout errors" do
    ArticleContentFetcherService.any_instance.stubs(:fetch).raises(Net::ReadTimeout.new("Timeout"))

    assert_raises(Net::ReadTimeout) do
      @job.perform(@article.id)
    end
  end

  test "perform propagates HTTP errors" do
    ArticleContentFetcherService.any_instance.stubs(:fetch).raises(HTTParty::Error.new("HTTP error"))

    assert_raises(HTTParty::Error) do
      @job.perform(@article.id)
    end
  end

  test "perform propagates socket errors" do
    ArticleContentFetcherService.any_instance.stubs(:fetch).raises(SocketError.new("Connection refused"))

    assert_raises(SocketError) do
      @job.perform(@article.id)
    end
  end

  # Job enqueuing
  test "can be enqueued" do
    assert_enqueued_with(job: ArticleContentFetchJob, args: [@article.id]) do
      ArticleContentFetchJob.perform_later(@article.id)
    end
  end

  test "enqueues to default queue" do
    assert_equal :default, ArticleContentFetchJob.new.queue_name
  end

  test "can enqueue multiple jobs for different articles" do
    article1 = articles(:tc_article_1)
    article2 = articles(:tc_article_2)

    assert_enqueued_jobs 2, only: ArticleContentFetchJob do
      ArticleContentFetchJob.perform_later(article1.id)
      ArticleContentFetchJob.perform_later(article2.id)
    end
  end

  test "perform_later accepts article_id as argument" do
    assert_nothing_raised do
      ArticleContentFetchJob.perform_later(@article.id)
    end
  end

  test "perform_now executes job immediately" do
    service_mock = mock("article_content_fetcher_service")
    service_mock.expects(:fetch).once

    ArticleContentFetcherService.expects(:new).with(@article).returns(service_mock)

    ArticleContentFetchJob.perform_now(@article.id)
  end

  # Edge cases
  test "perform handles string article_id" do
    service_mock = mock("article_content_fetcher_service")
    service_mock.expects(:fetch).returns(true)

    ArticleContentFetcherService.expects(:new).with(@article).returns(service_mock)

    @job.perform(@article.id.to_s)
  end

  test "perform handles negative article_id" do
    ArticleContentFetcherService.expects(:new).never

    assert_nothing_raised do
      @job.perform(-1)
    end
  end

  test "perform handles zero article_id" do
    ArticleContentFetcherService.expects(:new).never

    assert_nothing_raised do
      @job.perform(0)
    end
  end

  test "perform only creates one service instance" do
    ArticleContentFetcherService.expects(:new).once.returns(mock("service", fetch: true))

    @job.perform(@article.id)
  end

  test "perform uses find_by instead of find to avoid exception" do
    # This is implicitly tested by the "article not found" tests
    # find would raise ActiveRecord::RecordNotFound
    # find_by returns nil and the job handles it gracefully

    Article.expects(:find).never
    Article.expects(:find_by).with(id: 999999).returns(nil)

    @job.perform(999999)
  end

  test "perform works with all fixture articles" do
    articles(:tc_article_1, :tc_article_2, :hn_article_1, :ruby_article_1).each do |article|
      service_mock = mock("article_content_fetcher_service")
      service_mock.expects(:fetch).returns(true)

      ArticleContentFetcherService.expects(:new).with(article).returns(service_mock)

      assert_nothing_raised do
        @job.perform(article.id)
      end
    end
  end

  test "perform does not modify article record directly" do
    ArticleContentFetcherService.any_instance.stubs(:fetch).returns(true)

    @article.expects(:update).never
    @article.expects(:save).never

    @job.perform(@article.id)
  end

  test "multiple jobs can run concurrently without interference" do
    article1 = articles(:tc_article_1)
    article2 = articles(:tc_article_2)

    service1 = mock("service1")
    service1.expects(:fetch).returns(true)

    service2 = mock("service2")
    service2.expects(:fetch).returns(true)

    ArticleContentFetcherService.expects(:new).with(article1).returns(service1)
    ArticleContentFetcherService.expects(:new).with(article2).returns(service2)

    @job.perform(article1.id)
    ArticleContentFetchJob.new.perform(article2.id)
  end

  test "perform works for articles with no full_content" do
    article = articles(:tc_article_1)
    assert_nil article.full_content

    service_mock = mock("article_content_fetcher_service")
    service_mock.expects(:fetch).returns(true)

    ArticleContentFetcherService.expects(:new).with(article).returns(service_mock)

    @job.perform(article.id)
  end

  test "perform works for articles with existing full_content" do
    article = articles(:tc_article_2)
    assert_not_nil article.full_content

    service_mock = mock("article_content_fetcher_service")
    service_mock.expects(:fetch).returns(true)

    ArticleContentFetcherService.expects(:new).with(article).returns(service_mock)

    @job.perform(article.id)
  end

  test "perform can handle articles from different feeds" do
    tc_article = articles(:tc_article_1)
    hn_article = articles(:hn_article_1)

    ArticleContentFetcherService.any_instance.stubs(:fetch).returns(true)

    assert_nothing_raised do
      @job.perform(tc_article.id)
      @job.perform(hn_article.id)
    end
  end

  test "perform does not enqueue additional jobs" do
    ArticleContentFetcherService.any_instance.stubs(:fetch).returns(true)

    assert_no_enqueued_jobs do
      @job.perform(@article.id)
    end
  end
end
