require "test_helper"

class UserFeedRefreshJobTest < ActiveJob::TestCase
  setup do
    @user = users(:alice)
    @feeds = @user.feeds.distinct
  end

  test "enqueues feed refresh jobs for each user feed" do
    @feeds.each do |feed|
      FeedRefreshJob.expects(:perform_later).with(feed.id)
    end

    UserFeedRefreshJob.perform_now(@user.id)
  end

  test "does nothing when user not found" do
    FeedRefreshJob.expects(:perform_later).never
    UserFeedRefreshJob.perform_now(-1)
  end
end
