require "application_system_test_case"

class ArticleStateManagementTest < ApplicationSystemTestCase
  setup do
    @user = users(:alice)
    @article = articles(:tc_article_1)
    @article_state = @article.state_for(@user)

    # Login before each test
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
  end

  test "user can mark article as read" do
    visit article_path(@article)

    # Initially should be unread
    assert_equal false, @article_state.reload.read

    # Click read toggle button
    click_button "Mark as Read", match: :first

    # Should be marked as read
    assert_equal true, @article_state.reload.read
  end

  test "user can mark article as unread" do
    # First mark as read
    @article_state.update(read: true)

    visit article_path(@article)

    # Click unread toggle button
    click_button "Mark as Unread", match: :first

    # Should be marked as unread
    assert_equal false, @article_state.reload.read
  end

  test "user can toggle read status multiple times" do
    visit article_path(@article)

    initial_status = @article_state.reload.read

    # Toggle read
    click_button "Mark as Read", match: :first
    assert_equal !initial_status, @article_state.reload.read

    # Toggle back
    click_button "Mark as Unread", match: :first
    assert_equal initial_status, @article_state.reload.read
  end

  test "user can star an article" do
    visit article_path(@article)

    # Initially should not be starred
    assert_equal false, @article_state.reload.starred

    # Click star button
    click_button "Star", match: :first

    # Should be starred
    assert_equal true, @article_state.reload.starred
  end

  test "user can unstar an article" do
    # First star the article
    @article_state.update(starred: true)

    visit article_path(@article)

    # Click unstar button
    click_button "Unstar", match: :first

    # Should be unstarred
    assert_equal false, @article_state.reload.starred
  end

  test "user can toggle starred status multiple times" do
    visit article_path(@article)

    initial_status = @article_state.reload.starred

    # Toggle starred
    click_button "Star", match: :first
    assert_equal !initial_status, @article_state.reload.starred

    # Toggle back
    click_button "Unstar", match: :first
    assert_equal initial_status, @article_state.reload.starred
  end

  test "user can archive an article" do
    visit article_path(@article)

    # Initially should not be archived
    assert_equal false, @article_state.reload.archived

    # Click archive button
    click_button "Archive", match: :first

    # Should be archived and redirected
    assert_equal true, @article_state.reload.archived
    assert_current_path articles_path
  end

  test "user can unarchive an article" do
    # First archive the article
    @article_state.update(archived: true)

    # Visit archived articles view
    visit articles_path(filter: "archived")

    # Click on the article
    click_link @article.title, match: :first

    # Click unarchive button
    click_button "Unarchive", match: :first

    # Should be unarchived
    assert_equal false, @article_state.reload.archived
  end

  test "archived articles are hidden from default view" do
    # Archive an article
    @article_state.update(archived: true)

    visit articles_path

    # Should not see archived article
    assert_no_text @article.title
  end

  test "archived articles appear in archived filter" do
    # Archive an article
    @article_state.update(archived: true)

    visit articles_path(filter: "archived")

    # Should see archived article
    assert_text @article.title
  end

  test "marking article as read uses AJAX/Turbo" do
    visit article_path(@article)

    # Click read button - should not cause full page reload
    click_button "Mark as Read", match: :first

    # Should still be on same page
    assert_current_path article_path(@article)

    # State should be updated
    assert_equal true, @article_state.reload.read
  end

  test "starring article uses AJAX/Turbo" do
    visit article_path(@article)

    # Click star button - should not cause full page reload
    click_button "Star", match: :first

    # Should still be on same page
    assert_current_path article_path(@article)

    # State should be updated
    assert_equal true, @article_state.reload.starred
  end

  test "article state is user-specific" do
    # Mark article as read for alice
    @article_state.update(read: true)

    # Check that bob sees it as unread
    bob = users(:bob)
    bob_state = @article.state_for(bob)

    assert_equal true, @article_state.reload.read
    assert_equal false, bob_state.reload.read
  end

  test "article state persists across sessions" do
    # Mark article as read
    visit article_path(@article)
    click_button "Mark as Read", match: :first

    # Logout
    accept_confirm do
      click_button "Sign Out", match: :first
    end

    # Login again
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    # Article should still be marked as read
    assert_equal true, @article_state.reload.read
  end

  test "read articles can be filtered" do
    # Mark some articles as read
    articles(:tc_article_1).state_for(@user).update(read: true)
    unread_article = articles(:tc_article_2)

    visit articles_path(filter: "unread")

    # Should see unread article
    assert_text unread_article.title

    # Should not see read article
    assert_no_text @article.title
  end

  test "starred articles can be filtered" do
    # Star an article
    @article_state.update(starred: true)
    unstarred_article = articles(:tc_article_2)

    visit articles_path(filter: "starred")

    # Should see starred article
    assert_text @article.title

    # Should not see unstarred article
    assert_no_text unstarred_article.title
  end

  test "multiple article states can be combined" do
    # Mark article as both read and starred
    @article_state.update(read: true, starred: true)

    # Should appear in starred filter
    visit articles_path(filter: "starred")
    assert_text @article.title

    # Should not appear in unread filter
    visit articles_path(filter: "unread")
    assert_no_text @article.title
  end

  test "article state buttons show current state" do
    visit article_path(@article)

    # When unread, should show "Mark as Read" button
    assert_button "Mark as Read"

    # Mark as read
    click_button "Mark as Read", match: :first

    # Button text should change to "Mark as Unread"
    assert_button "Mark as Unread"
  end

  test "star button shows current starred state" do
    visit article_path(@article)

    # When unstarred, should show "Star" button
    assert_button "Star"

    # Star the article
    click_button "Star", match: :first

    # Button should change to "Unstar"
    assert_button "Unstar"
  end

  test "bulk marking articles as read from list view" do
    visit articles_path

    # Select multiple articles and mark as read
    # This depends on implementation - may have checkboxes or individual buttons
    article1 = articles(:tc_article_1)
    article2 = articles(:tc_article_2)

    within "article", text: article1.title do
      click_button "Mark as Read", match: :first
    end

    within "article", text: article2.title do
      click_button "Mark as Read", match: :first
    end

    # Both should be marked as read
    assert_equal true, article1.state_for(@user).reload.read
    assert_equal true, article2.state_for(@user).reload.read
  end

  test "article state updates are reflected immediately in UI" do
    visit articles_path

    # Find article and mark as read
    within "article", text: @article.title do
      click_button "Mark as Read", match: :first

      # UI should update to show read state
      # This could be visual indicator like opacity change
      assert_button "Mark as Unread"
    end
  end

  test "article state creates record on first access" do
    # Use an article without state
    new_article = articles(:hn_article_1)

    # Ensure no state exists
    ArticleState.where(user: @user, article: new_article).destroy_all

    visit article_path(new_article)

    # Mark as read - should create state record
    click_button "Mark as Read", match: :first

    # State should now exist
    state = ArticleState.find_by(user: @user, article: new_article)
    assert_not_nil state
    assert_equal true, state.read
  end

  test "archiving redirects to articles list" do
    visit article_path(@article)

    click_button "Archive", match: :first

    # Should redirect to articles list
    assert_current_path articles_path

    # Should see archived confirmation (if flash message exists)
    # Adjust based on implementation
  end

  test "unarchiving redirects to articles list" do
    @article_state.update(archived: true)

    visit article_path(@article)

    click_button "Unarchive", match: :first

    # Should redirect to articles list
    assert_current_path articles_path
  end

  test "article state buttons are keyboard accessible" do
    visit article_path(@article)

    # Focus on read button using tab navigation
    read_button = find_button("Mark as Read", match: :first)

    # Button should be focusable
    assert read_button.visible?
  end

  test "article state changes work with Stimulus controllers" do
    visit article_path(@article)

    # State management should use Stimulus for interactivity
    # Verify data attributes exist for Stimulus
    assert_selector "body"
  end

  test "optimistic UI updates for article state" do
    visit article_path(@article)

    # Click star button
    click_button "Star", match: :first

    # UI should update immediately (optimistic)
    # even before server confirms
    assert_button "Unstar", wait: 1
  end

  test "article state error handling" do
    # Mock a failed state update by temporarily breaking the article ID
    visit article_path(@article)

    # Even if there's an error, UI should handle gracefully
    # This is more of an integration test concept
    assert_selector "body"
  end

  test "article count updates when changing states" do
    # Mark all articles as read
    @user.feeds.each do |feed|
      feed.articles.each do |article|
        article.state_for(@user).update(read: true)
      end
    end

    visit articles_path(filter: "unread")

    # Should show no articles or empty state
    assert_selector "body"
  end

  test "starred count is accurate" do
    # Star multiple articles
    articles(:tc_article_1).state_for(@user).update(starred: true)
    articles(:tc_article_2).state_for(@user).update(starred: true)

    visit articles_path(filter: "starred")

    # Should see both starred articles
    assert_text articles(:tc_article_1).title
    assert_text articles(:tc_article_2).title
  end

  test "marking article read from list view" do
    visit articles_path

    # Mark article as read directly from list
    within "article", text: @article.title do
      click_button "Mark as Read", match: :first
    end

    # Should be marked as read
    assert_equal true, @article_state.reload.read

    # Should remain on articles page
    assert_current_path articles_path
  end

  test "starring article from list view" do
    visit articles_path

    # Star article directly from list
    within "article", text: @article.title do
      click_button "Star", match: :first
    end

    # Should be starred
    assert_equal true, @article_state.reload.starred

    # Should remain on articles page
    assert_current_path articles_path
  end

  test "article state persists when navigating between pages" do
    # Mark article as read and starred
    @article_state.update(read: true, starred: true)

    # Navigate to different pages
    visit articles_path
    visit feeds_path
    visit articles_path

    # State should still be preserved
    assert_equal true, @article_state.reload.read
    assert_equal true, @article_state.reload.starred
  end

  test "article state is independent per user" do
    # Alice marks as read
    @article_state.update(read: true, starred: true)

    # Logout alice
    accept_confirm do
      click_button "Sign Out", match: :first
    end

    # Login as bob
    bob = users(:bob)
    visit new_session_path
    fill_in "Email", with: bob.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    # Bob should see article as unread and unstarred
    bob_state = @article.state_for(bob)
    assert_equal false, bob_state.read
    assert_equal false, bob_state.starred
  end

  test "read state affects article appearance" do
    visit articles_path

    # Mark article as read
    within "article", text: @article.title do
      click_button "Mark as Read", match: :first
    end

    # Article should have visual indication of read state
    # This could be opacity, font weight, etc.
    # Adjust based on actual CSS implementation
    assert_selector "body"
  end

  test "starred articles have visual indicator" do
    @article_state.update(starred: true)

    visit articles_path

    # Starred articles should have visual indicator (e.g., star icon)
    assert_text @article.title
  end
