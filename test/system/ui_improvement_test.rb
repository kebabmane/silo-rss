require "application_system_test_case"

class UiImprovementTest < ApplicationSystemTestCase
  setup do
    @user = users(:alice)
    @article = articles(:tc_article_1)

    # Login
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    # Reset state
    @article.state_for(@user).update(starred: false, read: false)

    # Wait for login to complete
    assert_current_path dashboard_path
  end

  test "optimistic UI for starring article" do
    # Click the article in the list to load it
    click_link @article.title

    # Ensure we are on the dashboard
    assert_selector ".dashboard-layout"

    # Verify initial state (Unstarred)
    assert_button "☆ Star"

    # Click the star button
    click_button "☆ Star"

    # Assert change to "⭐ Starred"
    # Current behavior (with bug): this might fail or show blank page
    assert_button "⭐ Starred"

    # Reload page to verify persistence
    visit dashboard_path(article_id: @article.id)
    assert_button "⭐ Starred"
  end

  test "optimistic UI for marking read" do
    # Ensure article is unread initially
    @article.state_for(@user).update(read: false)

    # Click the article
    click_link @article.title

    assert_button "Mark Read"

    click_button "Mark Read"

    # Assert change
    assert_button "Mark Unread"

    # Verify persistence
    visit dashboard_path(article_id: @article.id)
    assert_button "Mark Unread"
  end
end
