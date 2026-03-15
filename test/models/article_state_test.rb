require "test_helper"

class ArticleStateTest < ActiveSupport::TestCase
  test "valid article state" do
    article_state = ArticleState.new(
      user: users(:charlie),
      article: articles(:tc_article_1),
      read: false,
      starred: false,
      archived: false
    )
    assert article_state.valid?
  end

  # Validation tests
  test "requires unique user_id scoped to article_id" do
    article_state = article_states(:alice_tc_1)
    duplicate = ArticleState.new(
      user: article_state.user,
      article: article_state.article,
      read: true,
      starred: false,
      archived: false
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "allows same user to have states for different articles" do
    user = users(:alice)
    article_state1 = article_states(:alice_tc_1)
    article_state2 = ArticleState.new(
      user: user,
      article: articles(:ruby_article_2),
      read: false,
      starred: false,
      archived: false
    )
    assert article_state2.valid?
  end

  test "allows different users to have states for same article" do
    article = articles(:tc_article_1)
    article_state1 = article_states(:alice_tc_1)
    article_state2 = ArticleState.new(
      user: users(:charlie),
      article: article,
      read: false,
      starred: false,
      archived: false
    )
    assert article_state2.valid?
  end

  # Association tests
  test "belongs to user" do
    article_state = article_states(:alice_tc_1)
    assert_respond_to article_state, :user
    assert_kind_of User, article_state.user
    assert_equal users(:alice), article_state.user
  end

  test "belongs to article" do
    article_state = article_states(:alice_tc_1)
    assert_respond_to article_state, :article
    assert_kind_of Article, article_state.article
    assert_equal articles(:tc_article_1), article_state.article
  end

  test "requires user" do
    article_state = ArticleState.new(
      article: articles(:tc_article_1),
      read: false,
      starred: false,
      archived: false
    )
    assert_not article_state.valid?
    assert_includes article_state.errors[:user], "must exist"
  end

  test "requires article" do
    article_state = ArticleState.new(
      user: users(:alice),
      read: false,
      starred: false,
      archived: false
    )
    assert_not article_state.valid?
    assert_includes article_state.errors[:article], "must exist"
  end

  # Scope tests
  test "unread scope returns only unread articles" do
    unread_states = ArticleState.unread
    assert_includes unread_states, article_states(:alice_tc_1)
    assert_includes unread_states, article_states(:alice_hn_1)
    assert_not_includes unread_states, article_states(:alice_tc_2)
    assert_not_includes unread_states, article_states(:bob_ruby_1)
  end

  test "unread scope only includes states with read false" do
    unread_states = ArticleState.unread
    unread_states.each do |state|
      assert_equal false, state.read, "Expected #{state.inspect} to be unread"
    end
  end

  test "starred scope returns only starred articles" do
    starred_states = ArticleState.starred
    assert_includes starred_states, article_states(:alice_tc_1)
    assert_includes starred_states, article_states(:bob_ruby_1)
    assert_not_includes starred_states, article_states(:alice_tc_2)
    assert_not_includes starred_states, article_states(:alice_hn_1)
  end

  test "starred scope only includes states with starred true" do
    starred_states = ArticleState.starred
    starred_states.each do |state|
      assert_equal true, state.starred, "Expected #{state.inspect} to be starred"
    end
  end

  test "archived scope returns only archived articles" do
    archived_states = ArticleState.archived
    assert_includes archived_states, article_states(:alice_tc_2)
    assert_not_includes archived_states, article_states(:alice_tc_1)
    assert_not_includes archived_states, article_states(:alice_hn_1)
    assert_not_includes archived_states, article_states(:bob_ruby_1)
  end

  test "archived scope only includes states with archived true" do
    archived_states = ArticleState.archived
    archived_states.each do |state|
      assert_equal true, state.archived, "Expected #{state.inspect} to be archived"
    end
  end

  test "can chain scopes" do
    # Create a starred and unread article state
    starred_unread = ArticleState.create!(
      user: users(:charlie),
      article: articles(:hn_article_1),
      read: false,
      starred: true,
      archived: false
    )

    starred_and_unread = ArticleState.starred.unread
    assert_includes starred_and_unread, starred_unread
    assert_not_includes starred_and_unread, article_states(:alice_tc_2) # read
    assert_not_includes starred_and_unread, article_states(:alice_hn_1) # not starred
  end

  # Boolean attribute tests
  test "read defaults to false" do
    article_state = ArticleState.new(
      user: users(:alice),
      article: articles(:tc_article_1)
    )
    assert_equal false, article_state.read
  end

  test "starred defaults to false" do
    article_state = ArticleState.new(
      user: users(:alice),
      article: articles(:tc_article_1)
    )
    assert_equal false, article_state.starred
  end

  test "archived defaults to false" do
    article_state = ArticleState.new(
      user: users(:alice),
      article: articles(:tc_article_1)
    )
    assert_equal false, article_state.archived
  end

  test "can be marked as read" do
    article_state = article_states(:alice_tc_1)
    assert_equal false, article_state.read
    article_state.update!(read: true)
    assert_equal true, article_state.reload.read
  end

  test "can be marked as unread" do
    article_state = article_states(:alice_tc_2)
    assert_equal true, article_state.read
    article_state.update!(read: false)
    assert_equal false, article_state.reload.read
  end

  test "can be starred" do
    article_state = article_states(:alice_tc_2)
    assert_equal false, article_state.starred
    article_state.update!(starred: true)
    assert_equal true, article_state.reload.starred
  end

  test "can be unstarred" do
    article_state = article_states(:alice_tc_1)
    assert_equal true, article_state.starred
    article_state.update!(starred: false)
    assert_equal false, article_state.reload.starred
  end

  test "can be archived" do
    article_state = article_states(:alice_tc_1)
    assert_equal false, article_state.archived
    article_state.update!(archived: true)
    assert_equal true, article_state.reload.archived
  end

  test "can be unarchived" do
    article_state = article_states(:alice_tc_2)
    assert_equal true, article_state.archived
    article_state.update!(archived: false)
    assert_equal false, article_state.reload.archived
  end

  # Edge cases
  test "can be read and starred simultaneously" do
    article_state = ArticleState.create!(
      user: users(:charlie),
      article: articles(:tc_article_1),
      read: true,
      starred: true,
      archived: false
    )
    assert article_state.valid?
    assert_equal true, article_state.read
    assert_equal true, article_state.starred
  end

  test "can be archived and starred simultaneously" do
    article_state = ArticleState.create!(
      user: users(:charlie),
      article: articles(:tc_article_1),
      read: false,
      starred: true,
      archived: true
    )
    assert article_state.valid?
    assert_equal true, article_state.starred
    assert_equal true, article_state.archived
  end

  test "can be read, starred, and archived simultaneously" do
    article_state = ArticleState.create!(
      user: users(:charlie),
      article: articles(:tc_article_1),
      read: true,
      starred: true,
      archived: true
    )
    assert article_state.valid?
    assert_equal true, article_state.read
    assert_equal true, article_state.starred
    assert_equal true, article_state.archived
  end

  test "can toggle all boolean fields independently" do
    article_state = ArticleState.create!(
      user: users(:charlie),
      article: articles(:tc_article_1),
      read: false,
      starred: false,
      archived: false
    )

    article_state.update!(read: true)
    assert_equal true, article_state.reload.read
    assert_equal false, article_state.starred
    assert_equal false, article_state.archived

    article_state.update!(starred: true)
    assert_equal true, article_state.reload.read
    assert_equal true, article_state.starred
    assert_equal false, article_state.archived

    article_state.update!(archived: true)
    assert_equal true, article_state.reload.read
    assert_equal true, article_state.starred
    assert_equal true, article_state.archived
  end

  test "scopes work with freshly created states" do
    article_state = ArticleState.create!(
      user: users(:charlie),
      article: articles(:tc_article_1),
      read: false,
      starred: true,
      archived: false
    )

    assert_includes ArticleState.unread, article_state
    assert_includes ArticleState.starred, article_state
    assert_not_includes ArticleState.archived, article_state
  end
end
