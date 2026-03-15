require "test_helper"

class Admin::SuggestedFeedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:alice)
    @non_admin = users(:bob)
    @suggested_feed = suggested_feeds(:tech_crunch_suggested)
  end

  # Authorization tests
  test "requires admin authentication for index" do
    login_as @non_admin

    get admin_suggested_feeds_url

    assert_redirected_to dashboard_path
    assert_equal "You are not authorized to access that area.", flash[:alert]
  end

  test "requires admin authentication for new" do
    login_as @non_admin

    get new_admin_suggested_feed_url

    assert_redirected_to dashboard_path
    assert_equal "You are not authorized to access that area.", flash[:alert]
  end

  test "requires admin authentication for create" do
    login_as @non_admin

    assert_no_difference "SuggestedFeed.count" do
      post admin_suggested_feeds_url, params: {
        suggested_feed: {
          title: "New Feed",
          feed_url: "https://example.com/feed.xml",
          category: "Technology"
        }
      }
    end

    assert_redirected_to dashboard_path
    assert_equal "You are not authorized to access that area.", flash[:alert]
  end

  test "requires admin authentication for edit" do
    login_as @non_admin

    get edit_admin_suggested_feed_url(@suggested_feed)

    assert_redirected_to dashboard_path
    assert_equal "You are not authorized to access that area.", flash[:alert]
  end

  test "requires admin authentication for update" do
    login_as @non_admin

    patch admin_suggested_feed_url(@suggested_feed), params: {
      suggested_feed: { title: "Updated Title" }
    }

    assert_redirected_to dashboard_path
    assert_equal "You are not authorized to access that area.", flash[:alert]
  end

  test "requires admin authentication for destroy" do
    login_as @non_admin

    assert_no_difference "SuggestedFeed.count" do
      delete admin_suggested_feed_url(@suggested_feed)
    end

    assert_redirected_to dashboard_path
    assert_equal "You are not authorized to access that area.", flash[:alert]
  end

  test "redirects to login when not authenticated" do
    get admin_suggested_feeds_url

    assert_redirected_to new_session_path
  end

  # Index action tests
  test "should get index when admin" do
    login_as @admin

    get admin_suggested_feeds_url

    assert_response :success
  end

  test "index loads all suggested feeds" do
    login_as @admin

    get admin_suggested_feeds_url

    assert_response :success
    assert assigns(:suggested_feeds).count >= 10
  end

  test "index loads suggested feeds in order" do
    login_as @admin

    get admin_suggested_feeds_url

    assert_response :success
    feeds = assigns(:suggested_feeds)
    display_orders = feeds.map(&:display_order).compact
    assert_equal display_orders.sort, display_orders
  end

  test "index loads categories" do
    login_as @admin

    get admin_suggested_feeds_url

    assert_response :success
    categories = assigns(:categories)
    assert_kind_of Array, categories
    assert_includes categories, "Technology"
  end

  # New action tests
  test "should get new when admin" do
    login_as @admin

    get new_admin_suggested_feed_url

    assert_response :success
  end

  test "new initializes a new suggested feed" do
    login_as @admin

    get new_admin_suggested_feed_url

    assert_response :success
    assert assigns(:suggested_feed).new_record?
  end

  test "new loads categories" do
    login_as @admin

    get new_admin_suggested_feed_url

    assert_response :success
    assert_not_nil assigns(:categories)
  end

  # Create action tests
  test "should create suggested feed when admin" do
    login_as @admin

    assert_difference "SuggestedFeed.count", 1 do
      post admin_suggested_feeds_url, params: {
        suggested_feed: {
          title: "New Tech Feed",
          feed_url: "https://newtechfeed.com/rss",
          category: "Technology",
          description: "A new tech feed",
          display_order: 100
        }
      }
    end

    assert_redirected_to admin_suggested_feeds_path
    assert_equal "Suggested feed added successfully.", flash[:notice]
  end

  test "create saves with correct attributes" do
    login_as @admin

    post admin_suggested_feeds_url, params: {
      suggested_feed: {
        title: "Test Feed",
        feed_url: "https://test.com/feed.xml",
        category: "Testing",
        description: "Test description",
        display_order: 42
      }
    }

    feed = SuggestedFeed.find_by(title: "Test Feed")
    assert_not_nil feed
    assert_equal "https://test.com/feed.xml", feed.feed_url
    assert_equal "Testing", feed.category
    assert_equal "Test description", feed.description
    assert_equal 42, feed.display_order
  end

  test "create without display_order" do
    login_as @admin

    assert_difference "SuggestedFeed.count", 1 do
      post admin_suggested_feeds_url, params: {
        suggested_feed: {
          title: "Feed Without Order",
          feed_url: "https://noorder.com/feed.xml",
          category: "Technology"
        }
      }
    end

    assert_redirected_to admin_suggested_feeds_path
  end

  test "create without description" do
    login_as @admin

    assert_difference "SuggestedFeed.count", 1 do
      post admin_suggested_feeds_url, params: {
        suggested_feed: {
          title: "Feed Without Description",
          feed_url: "https://nodesc.com/feed.xml",
          category: "Technology"
        }
      }
    end

    assert_redirected_to admin_suggested_feeds_path
  end

  test "create with invalid attributes renders new" do
    login_as @admin

    assert_no_difference "SuggestedFeed.count" do
      post admin_suggested_feeds_url, params: {
        suggested_feed: {
          title: "",
          feed_url: "",
          category: ""
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create with duplicate feed_url renders new" do
    login_as @admin

    assert_no_difference "SuggestedFeed.count" do
      post admin_suggested_feeds_url, params: {
        suggested_feed: {
          title: "Duplicate",
          feed_url: @suggested_feed.feed_url,
          category: "Technology"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create loads categories on failure" do
    login_as @admin

    post admin_suggested_feeds_url, params: {
      suggested_feed: { title: "", feed_url: "", category: "" }
    }

    assert_response :unprocessable_entity
    assert_not_nil assigns(:categories)
  end

  # Edit action tests
  test "should get edit when admin" do
    login_as @admin

    get edit_admin_suggested_feed_url(@suggested_feed)

    assert_response :success
  end

  test "edit loads the correct suggested feed" do
    login_as @admin

    get edit_admin_suggested_feed_url(@suggested_feed)

    assert_response :success
    assert_equal @suggested_feed, assigns(:suggested_feed)
  end

  test "edit loads categories" do
    login_as @admin

    get edit_admin_suggested_feed_url(@suggested_feed)

    assert_response :success
    assert_not_nil assigns(:categories)
  end

  test "edit handles non-existent feed" do
    login_as @admin

    get edit_admin_suggested_feed_url(id: 999999)

    assert_response :not_found
  end

  # Update action tests
  test "should update suggested feed when admin" do
    login_as @admin

    patch admin_suggested_feed_url(@suggested_feed), params: {
      suggested_feed: { title: "Updated Title" }
    }

    assert_redirected_to admin_suggested_feeds_path
    assert_equal "Suggested feed updated successfully.", flash[:notice]
    assert_equal "Updated Title", @suggested_feed.reload.title
  end

  test "update can change all attributes" do
    login_as @admin

    patch admin_suggested_feed_url(@suggested_feed), params: {
      suggested_feed: {
        title: "New Title",
        feed_url: "https://newtechcrunch.com/feed/",
        category: "News",
        description: "New description",
        display_order: 999
      }
    }

    @suggested_feed.reload
    assert_equal "New Title", @suggested_feed.title
    assert_equal "https://newtechcrunch.com/feed/", @suggested_feed.feed_url
    assert_equal "News", @suggested_feed.category
    assert_equal "New description", @suggested_feed.description
    assert_equal 999, @suggested_feed.display_order
  end

  test "update with invalid attributes renders edit" do
    login_as @admin

    patch admin_suggested_feed_url(@suggested_feed), params: {
      suggested_feed: { title: "" }
    }

    assert_response :unprocessable_entity
    assert_not_equal "", @suggested_feed.reload.title
  end

  test "update with duplicate feed_url renders edit" do
    login_as @admin
    other_feed = suggested_feeds(:hacker_news_suggested)

    patch admin_suggested_feed_url(@suggested_feed), params: {
      suggested_feed: { feed_url: other_feed.feed_url }
    }

    assert_response :unprocessable_entity
  end

  test "update loads categories on failure" do
    login_as @admin

    patch admin_suggested_feed_url(@suggested_feed), params: {
      suggested_feed: { title: "" }
    }

    assert_response :unprocessable_entity
    assert_not_nil assigns(:categories)
  end

  test "update handles non-existent feed" do
    login_as @admin

    patch admin_suggested_feed_url(id: 999999), params: {
      suggested_feed: { title: "New Title" }
    }

    assert_response :not_found
  end

  # Destroy action tests
  test "should destroy suggested feed when admin" do
    login_as @admin

    assert_difference "SuggestedFeed.count", -1 do
      delete admin_suggested_feed_url(@suggested_feed)
    end

    assert_redirected_to admin_suggested_feeds_path
    assert_equal "Suggested feed removed successfully.", flash[:notice]
  end

  test "destroy removes the correct feed" do
    login_as @admin
    feed_id = @suggested_feed.id

    delete admin_suggested_feed_url(@suggested_feed)

    assert_not SuggestedFeed.exists?(feed_id)
  end

  test "destroy handles non-existent feed" do
    login_as @admin

    delete admin_suggested_feed_url(id: 999999)

    assert_response :not_found
  end

  # Parameter filtering tests
  test "create ignores unpermitted parameters" do
    login_as @admin

    post admin_suggested_feeds_url, params: {
      suggested_feed: {
        title: "Test",
        feed_url: "https://test.com/feed.xml",
        category: "Technology",
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      }
    }

    feed = SuggestedFeed.find_by(title: "Test")
    assert_not_equal 1.year.ago.to_date, feed.created_at.to_date
  end

  test "update ignores unpermitted parameters" do
    login_as @admin
    original_created_at = @suggested_feed.created_at

    patch admin_suggested_feed_url(@suggested_feed), params: {
      suggested_feed: {
        title: "Updated",
        created_at: 1.year.ago
      }
    }

    @suggested_feed.reload
    assert_equal "Updated", @suggested_feed.title
    assert_equal original_created_at.to_i, @suggested_feed.created_at.to_i
  end

  # Edge cases
  test "handles very long values in create" do
    login_as @admin

    post admin_suggested_feeds_url, params: {
      suggested_feed: {
        title: "a" * 500,
        feed_url: "https://example.com/" + ("b" * 500) + ".xml",
        category: "c" * 500,
        description: "d" * 5000
      }
    }

    # Should either succeed (redirect) or fail gracefully (unprocessable_entity)
    assert [302, 303, 307, 308, 422].include?(response.status), "Response status #{response.status} not in expected range"
  end

  test "handles special characters in inputs" do
    login_as @admin

    assert_difference "SuggestedFeed.count", 1 do
      post admin_suggested_feeds_url, params: {
        suggested_feed: {
          title: "Feed & Co. <script>alert('xss')</script>",
          feed_url: "https://example.com/feed?param=value&other=123",
          category: "Tech & News",
          description: "Description with special chars: !@#$%^&*()"
        }
      }
    end

    assert_redirected_to admin_suggested_feeds_path
  end
end
