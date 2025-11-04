require "test_helper"

class Admin::FeedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:alice) # alice is admin
    @user = users(:bob)
    @tech_crunch = feeds(:tech_crunch)
    @hacker_news = feeds(:hacker_news)
    @ruby_weekly = feeds(:ruby_weekly)
  end

  test "should require admin access" do
    login_as @user
    get admin_feeds_path
    assert_redirected_to dashboard_path
  end

  test "should show all feeds with subscriber counts" do
    login_as @admin
    get admin_feeds_path
    assert_response :success
    assert_select "table" # Table should be present
  end

  test "should display orphaned feeds count" do
    login_as @admin

    # Create a feed with no subscribers
    orphaned_feed = Feed.create!(
      title: "Orphaned Feed",
      feed_url: "http://example.com/orphaned.xml"
    )

    get admin_feeds_path
    assert_response :success
    assert_match /Orphaned/, response.body
  end

  test "should delete orphaned feed" do
    login_as @admin

    # Create a feed with no subscribers
    orphaned_feed = Feed.create!(
      title: "Orphaned Feed",
      feed_url: "http://example.com/orphaned.xml"
    )

    assert_difference "Feed.count", -1 do
      delete admin_feed_path(orphaned_feed)
    end

    assert_redirected_to admin_feeds_path
  end

  test "should not allow deleting feed with subscribers" do
    login_as @admin

    # tech_crunch has subscribers
    assert @tech_crunch.subscriptions.any?

    assert_no_difference "Feed.count" do
      delete admin_feed_path(@tech_crunch)
    end

    assert_redirected_to admin_feeds_path
    assert_match /Cannot delete feed with active subscribers/, flash[:alert]
  end
end
