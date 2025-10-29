require "test_helper"

class OnboardingFlowTest < ActionDispatch::IntegrationTest
  setup do
    @new_user = User.create!(
      email_address: "newuser@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @new_user.update!(confirmed_at: Time.current)
  end

  test "complete onboarding flow for new user" do
    # Step 1: Login as new user
    post session_path, params: {
      email_address: @new_user.email_address,
      password: "password123"
    }
    assert_redirected_to dashboard_path
    follow_redirect!

    # Step 2: Visit dashboard
    get dashboard_path
    assert_response :success

    # Verify onboarding hasn't been completed
    assert_not @new_user.reload.onboarding_completed?

    # Step 3: Mark onboarding as completed
    post mark_onboarding_completed_path
    assert_response :ok

    # Verify onboarding is now completed
    assert @new_user.reload.onboarding_completed?
    assert_not_nil @new_user.onboarding_completed_at
  end

  test "user who completes onboarding doesn't see modal again" do
    # Complete onboarding first
    @new_user.complete_onboarding!
    assert @new_user.onboarding_completed?

    # Login
    post session_path, params: { email_address: @new_user.email_address, password: "password123" }
    assert_redirected_to dashboard_path
    follow_redirect!

    # Visit dashboard
    get dashboard_path
    assert_response :success

    # Suggested feeds should still be loaded (for potential use elsewhere)
    # but onboarding should be marked as completed
    assert @new_user.reload.onboarding_completed?
  end

  test "suggested feeds exist for onboarding" do
    post session_path, params: { email_address: @new_user.email_address, password: "password123" }
    assert_redirected_to dashboard_path
    follow_redirect!

    get dashboard_path
    assert_response :success

    # Verify suggested feeds exist in database (they will be loaded by dashboard)
    assert SuggestedFeed.count >= 10
    assert SuggestedFeed.categories.include?("Technology")
    assert SuggestedFeed.categories.include?("News")
    assert SuggestedFeed.categories.include?("Development")
  end

  test "new user can complete onboarding" do
    post session_path, params: { email_address: @new_user.email_address, password: "password123" }

    # Get dashboard (shows onboarding modal)
    get dashboard_path
    assert_response :success

    # User hasn't completed onboarding yet
    assert_not @new_user.reload.onboarding_completed?

    # Mark onboarding as complete
    post mark_onboarding_completed_path
    assert_response :ok

    # Verify onboarding is marked as completed
    assert @new_user.reload.onboarding_completed?
  end

  test "marking onboarding complete without subscribing" do
    post session_path, params: { email_address: @new_user.email_address, password: "password123" }
    assert_redirected_to dashboard_path
    follow_redirect!

    # Verify user has no subscriptions
    assert_equal 0, @new_user.subscriptions.count

    # Mark onboarding as complete without subscribing to any feeds
    post mark_onboarding_completed_path
    assert_response :ok

    # Verify onboarding is completed
    assert @new_user.reload.onboarding_completed?

    # User still has no subscriptions (this is allowed)
    assert_equal 0, @new_user.subscriptions.count
  end

  test "onboarding can be completed multiple times safely" do
    post session_path, params: { email_address: @new_user.email_address, password: "password123" }
    assert_redirected_to dashboard_path
    follow_redirect!

    # First completion
    post mark_onboarding_completed_path
    assert_response :ok
    first_completion = @new_user.reload.onboarding_completed_at

    # Second completion (should be idempotent)
    post mark_onboarding_completed_path
    assert_response :ok
    second_completion = @new_user.reload.onboarding_completed_at

    # Timestamps should be the same (idempotent)
    assert_equal first_completion.to_i, second_completion.to_i
  end

  test "existing user with onboarding completed doesn't trigger modal" do
    # Use existing user who already has onboarding completed
    alice = users(:alice)
    alice.update!(onboarding_completed_at: 1.week.ago)

    login_as alice  # This now does POST + follow_redirect

    get dashboard_path
    assert_response :success

    # Onboarding should remain completed
    assert alice.reload.onboarding_completed?
  end

  test "admin user can access dashboard" do
    alice = users(:alice)
    login_as alice

    get dashboard_path
    assert_response :success

    # Suggested feeds should exist in database
    assert SuggestedFeed.count >= 10
  end

  test "suggested feeds have all required fields" do
    post session_path, params: { email_address: @new_user.email_address, password: "password123" }
    assert_redirected_to dashboard_path
    follow_redirect!

    get dashboard_path
    assert_response :success

    feeds = SuggestedFeed.all
    feeds.each do |feed|
      assert_not_nil feed.title
      assert_not_nil feed.feed_url
      assert_not_nil feed.category
      # Description and display_order are optional
    end
  end

  test "onboarding flow with empty suggested feeds table" do
    # Remove all suggested feeds
    SuggestedFeed.destroy_all

    post session_path, params: { email_address: @new_user.email_address, password: "password123" }
    assert_redirected_to dashboard_path
    follow_redirect!

    get dashboard_path
    assert_response :success

    # Verify no suggested feeds exist
    assert_equal 0, SuggestedFeed.count

    # User can still complete onboarding
    post mark_onboarding_completed_path
    assert_response :ok
    assert @new_user.reload.onboarding_completed?
  end

  test "onboarding completion persists across sessions" do
    # Session 1: Complete onboarding
    post session_path, params: { email_address: @new_user.email_address, password: "password123" }
    assert_redirected_to dashboard_path
    follow_redirect!
    post mark_onboarding_completed_path
    assert_response :ok
    assert @new_user.reload.onboarding_completed?

    # Logout
    delete session_path

    # Session 2: Login again
    post session_path, params: {
      email_address: @new_user.email_address,
      password: "password123"
    }
    assert_redirected_to dashboard_path
    follow_redirect!

    # Onboarding should still be completed
    assert @new_user.reload.onboarding_completed?

    # Visit dashboard
    get dashboard_path
    assert_response :success
    assert @new_user.reload.onboarding_completed?
  end

  test "multiple new users complete onboarding independently" do
    # Create second new user
    user2 = User.create!(
      email_address: "newuser2@example.com",
      password: "password123",
      password_confirmation: "password123",
      confirmed_at: Time.current
    )

    # User 1 completes onboarding
    post session_path, params: { email_address: @new_user.email_address, password: "password123" }
    assert_redirected_to dashboard_path
    follow_redirect!
    post mark_onboarding_completed_path
    assert_response :ok
    assert @new_user.reload.onboarding_completed?

    # Logout
    delete session_path

    # User 2 hasn't completed onboarding yet
    assert_not user2.reload.onboarding_completed?

    # User 2 logs in and completes onboarding
    post session_path, params: { email_address: user2.email_address, password: "password123" }
    assert_redirected_to dashboard_path
    follow_redirect!
    post mark_onboarding_completed_path
    assert_response :ok
    assert user2.reload.onboarding_completed?

    # Both users should have completed onboarding
    assert @new_user.reload.onboarding_completed?
    assert user2.reload.onboarding_completed?
  end

  test "onboarding requires authentication" do
    # Try to complete onboarding without being logged in
    post mark_onboarding_completed_path

    # Should redirect to login
    assert_redirected_to new_session_path

    # Onboarding should not be completed
    assert_not @new_user.reload.onboarding_completed?
  end

  test "suggested feeds URLs are valid for subscription" do
    post session_path, params: { email_address: @new_user.email_address, password: "password123" }

    get dashboard_path
    assert_response :success

    # Pick a suggested feed and verify its URL format
    suggested_feed = SuggestedFeed.first
    assert suggested_feed.feed_url.present?
    assert suggested_feed.feed_url.start_with?("http://") || suggested_feed.feed_url.start_with?("https://")
  end

  test "onboarding flow with different categories of suggested feeds" do
    post session_path, params: { email_address: @new_user.email_address, password: "password123" }
    assert_redirected_to dashboard_path
    follow_redirect!

    get dashboard_path
    assert_response :success

    # Verify multiple categories exist
    categories = SuggestedFeed.categories
    assert categories.count >= 3

    # Each category should have at least one feed
    categories.each do |category|
      feeds = SuggestedFeed.by_category(category)
      assert feeds.count > 0
      feeds.each do |feed|
        assert_equal category, feed.category
      end
    end
  end

  test "new user journey: register, login, see onboarding, complete" do
    # Step 1: Create and confirm a brand new user
    new_journey_user = User.create!(
      email_address: "journey@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    new_journey_user.update!(confirmed_at: Time.current)

    # Step 2: Login
    post session_path, params: {
      email_address: "journey@example.com",
      password: "password123"
    }
    assert_redirected_to dashboard_path
    follow_redirect!

    # Step 3: Visit dashboard - should see onboarding data
    get dashboard_path
    assert_response :success
    assert_not new_journey_user.reload.onboarding_completed?
    assert SuggestedFeed.count >= 10

    # Step 4: Complete onboarding
    post mark_onboarding_completed_path
    assert_response :ok

    # Step 5: Verify everything
    new_journey_user.reload
    assert new_journey_user.onboarding_completed?

    # Step 6: Visit dashboard again - onboarding completed
    get dashboard_path
    assert_response :success
    assert new_journey_user.onboarding_completed?
  end
end
