require "test_helper"

module Api
  module V1
    class ArticlesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @alice = users(:alice)
        @bob = users(:bob)
        @tech_crunch = feeds(:tech_crunch)
        @hacker_news = feeds(:hacker_news)
        @ruby_weekly = feeds(:ruby_weekly)
        @tc_article_1 = articles(:tc_article_1)
        @tc_article_2 = articles(:tc_article_2)
        @hn_article_1 = articles(:hn_article_1)
        @ruby_article_1 = articles(:ruby_article_1)
      end

      # GET /api/v1/articles
      test "index returns articles for authenticated user's subscriptions" do
        get api_v1_articles_url, headers: api_headers(@alice), as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("articles")
        assert json.key?("meta")
        assert_equal 2, json["articles"].length

        # Alice has subscriptions to tech_crunch and hacker_news
        # tc_article_2 is archived so it's excluded
        article_ids = json["articles"].map { |a| a["id"] }
        assert_includes article_ids, @tc_article_1.id
        assert_not_includes article_ids, @tc_article_2.id
        assert_includes article_ids, @hn_article_1.id
        assert_not_includes article_ids, @ruby_article_1.id
      end

      test "index returns correct article structure" do
        get api_v1_articles_url, headers: api_headers(@alice), as: :json

        assert_response :success
        json = JSON.parse(response.body)
        article = json["articles"].first

        assert article.key?("id")
        assert article.key?("title")
        assert article.key?("content")
        assert article.key?("url")
        assert article.key?("published_at")
        assert article.key?("feed")
        assert article.key?("state")

        # Feed structure
        assert article["feed"].key?("id")
        assert article["feed"].key?("title")

        # State structure
        assert article["state"].key?("read")
        assert article["state"].key?("starred")
        assert article["state"].key?("archived")
      end

      test "index returns correct meta information" do
        get api_v1_articles_url, headers: api_headers(@alice), as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json["meta"].key?("total")
        assert json["meta"].key?("limit")
        assert json["meta"].key?("offset")
        assert_equal 50, json["meta"]["limit"]
        assert_equal 0, json["meta"]["offset"]
      end

      test "index excludes archived articles by default" do
        get api_v1_articles_url, headers: api_headers(@alice), as: :json

        assert_response :success
        json = JSON.parse(response.body)

        article_ids = json["articles"].map { |a| a["id"] }
        # tc_article_2 is archived for alice
        assert_not_includes article_ids, @tc_article_2.id
      end

      test "index filters by feed_id" do
        get api_v1_articles_url,
            params: { feed_id: @tech_crunch.id },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        # Only tc_article_1 is returned (tc_article_2 is archived)
        assert_equal 1, json["articles"].length
        json["articles"].each do |article|
          assert_equal @tech_crunch.id, article["feed"]["id"]
        end
      end

      test "index filters by category" do
        get api_v1_articles_url,
            params: { category: "Technology" },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        # Alice has Technology subscriptions for tech_crunch and hacker_news
        assert json["articles"].length >= 2
      end

      test "index filters unread articles" do
        get api_v1_articles_url,
            params: { filter: "unread" },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        json["articles"].each do |article|
          assert_equal false, article["state"]["read"]
        end
      end

      test "index filters starred articles" do
        get api_v1_articles_url,
            params: { filter: "starred" },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json["articles"].length >= 1
        json["articles"].each do |article|
          assert_equal true, article["state"]["starred"]
        end
      end

      test "index filters archived articles" do
        get api_v1_articles_url,
            params: { filter: "archived" },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json["articles"].length >= 1
        json["articles"].each do |article|
          assert_equal true, article["state"]["archived"]
        end
      end

      test "index respects limit parameter" do
        get api_v1_articles_url,
            params: { limit: 1 },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert_equal 1, json["articles"].length
        assert_equal 1, json["meta"]["limit"]
      end

      test "index respects offset parameter" do
        get api_v1_articles_url,
            params: { limit: 1, offset: 1 },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert_equal 1, json["meta"]["offset"]
      end

      test "index requires authentication" do
        get api_v1_articles_url, as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)
        assert_equal "Unauthorized", json["error"]
      end

      test "index returns unauthorized with invalid token" do
        get api_v1_articles_url,
            headers: { "Authorization" => "Bearer invalid_token" },
            as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)
        assert_equal "Unauthorized", json["error"]
      end

      test "index returns articles with correct state for user" do
        get api_v1_articles_url, headers: api_headers(@alice), as: :json

        assert_response :success
        json = JSON.parse(response.body)

        tc_1 = json["articles"].find { |a| a["id"] == @tc_article_1.id }
        assert_not_nil tc_1
        assert_equal false, tc_1["state"]["read"]
        assert_equal true, tc_1["state"]["starred"]
        assert_equal false, tc_1["state"]["archived"]

        # tc_article_2 is archived so it's not returned
        tc_2 = json["articles"].find { |a| a["id"] == @tc_article_2.id }
        assert_nil tc_2

        # Check hn_article_1 instead
        hn_1 = json["articles"].find { |a| a["id"] == @hn_article_1.id }
        assert_not_nil hn_1
        assert_equal false, hn_1["state"]["read"]
        assert_equal false, hn_1["state"]["starred"]
        assert_equal false, hn_1["state"]["archived"]
      end

      # GET /api/v1/articles/:id
      test "show returns article for authenticated user" do
        get api_v1_article_url(@tc_article_1),
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("article")
        assert_equal @tc_article_1.id, json["article"]["id"]
        assert_equal @tc_article_1.title, json["article"]["title"]
        assert_equal @tc_article_1.content, json["article"]["content"]
        assert_equal @tc_article_1.url, json["article"]["url"]
      end

      test "show returns correct article structure" do
        get api_v1_article_url(@tc_article_1),
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)
        article = json["article"]

        assert article.key?("id")
        assert article.key?("title")
        assert article.key?("content")
        assert article.key?("url")
        assert article.key?("published_at")
        assert article.key?("feed")
        assert article.key?("state")

        # Feed includes site_url for show action
        assert article["feed"].key?("id")
        assert article["feed"].key?("title")
        assert article["feed"].key?("site_url")

        # State structure
        assert article["state"].key?("read")
        assert article["state"].key?("starred")
        assert article["state"].key?("archived")
      end

      test "show returns article with correct state" do
        get api_v1_article_url(@tc_article_1),
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert_equal false, json["article"]["state"]["read"]
        assert_equal true, json["article"]["state"]["starred"]
        assert_equal false, json["article"]["state"]["archived"]
      end

      test "show requires authentication" do
        get api_v1_article_url(@tc_article_1), as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)
        assert_equal "Unauthorized", json["error"]
      end

      test "show returns not found for article not in user subscriptions" do
        get api_v1_article_url(@ruby_article_1),
            headers: api_headers(@alice),
            as: :json

        assert_response :not_found
        json = JSON.parse(response.body)
        assert json["error"].present?
      end

      test "show returns not found for non-existent article" do
        get api_v1_article_url(id: 99999),
            headers: api_headers(@alice),
            as: :json

        assert_response :not_found
        json = JSON.parse(response.body)
        assert json["error"].present?
      end

      # PATCH /api/v1/articles/:id/mark_read
      test "mark_read sets article as read" do
        patch mark_read_api_v1_article_url(@tc_article_1),
              params: { read: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("state")
        assert_equal true, json["state"]["read"]
      end

      test "mark_read sets article as unread" do
        patch mark_read_api_v1_article_url(@tc_article_2),
              params: { read: false },
              headers: api_headers(@alice),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("state")
        assert_equal false, json["state"]["read"]
      end

      test "mark_read creates state if it does not exist" do
        # Create a new article without a state for alice
        new_article = Article.create!(
          feed: @tech_crunch,
          title: "New Article",
          content: "New content",
          url: "https://example.com/new",
          guid: "new_article_guid",
          published_at: Time.current
        )

        patch mark_read_api_v1_article_url(new_article),
              params: { read: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert_equal true, json["state"]["read"]
      end

      test "mark_read requires authentication" do
        patch mark_read_api_v1_article_url(@tc_article_1),
              params: { read: true },
              as: :json

        assert_response :unauthorized
      end

      test "mark_read returns not found for non-existent article" do
        patch mark_read_api_v1_article_url(id: 99999),
              params: { read: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :not_found
      end

      # PATCH /api/v1/articles/:id/mark_starred
      test "mark_starred sets article as starred" do
        patch mark_starred_api_v1_article_url(@tc_article_2),
              params: { starred: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("state")
        assert_equal true, json["state"]["starred"]
      end

      test "mark_starred sets article as unstarred" do
        patch mark_starred_api_v1_article_url(@tc_article_1),
              params: { starred: false },
              headers: api_headers(@alice),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("state")
        assert_equal false, json["state"]["starred"]
      end

      test "mark_starred creates state if it does not exist" do
        new_article = Article.create!(
          feed: @tech_crunch,
          title: "New Article for Star",
          content: "New content",
          url: "https://example.com/new-star",
          guid: "new_star_article_guid",
          published_at: Time.current
        )

        patch mark_starred_api_v1_article_url(new_article),
              params: { starred: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert_equal true, json["state"]["starred"]
      end

      test "mark_starred requires authentication" do
        patch mark_starred_api_v1_article_url(@tc_article_1),
              params: { starred: true },
              as: :json

        assert_response :unauthorized
      end

      test "mark_starred returns not found for non-existent article" do
        patch mark_starred_api_v1_article_url(id: 99999),
              params: { starred: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :not_found
      end

      # PATCH /api/v1/articles/:id/mark_archived
      test "mark_archived sets article as archived" do
        patch mark_archived_api_v1_article_url(@tc_article_1),
              params: { archived: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("state")
        assert_equal true, json["state"]["archived"]
      end

      test "mark_archived sets article as unarchived" do
        patch mark_archived_api_v1_article_url(@hn_article_1),
              params: { archived: false },
              headers: api_headers(@alice),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("state")
        assert_equal false, json["state"]["archived"]
      end

      test "mark_archived creates state if it does not exist" do
        new_article = Article.create!(
          feed: @tech_crunch,
          title: "New Article for Archive",
          content: "New content",
          url: "https://example.com/new-archive",
          guid: "new_archive_article_guid",
          published_at: Time.current
        )

        patch mark_archived_api_v1_article_url(new_article),
              params: { archived: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert_equal true, json["state"]["archived"]
      end

      test "mark_archived requires authentication" do
        patch mark_archived_api_v1_article_url(@tc_article_1),
              params: { archived: true },
              as: :json

        assert_response :unauthorized
      end

      test "mark_archived returns not found for non-existent article" do
        patch mark_archived_api_v1_article_url(id: 99999),
              params: { archived: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :not_found
      end

      # GET /api/v1/articles/search
      test "search returns articles matching query" do
        get search_api_v1_articles_url,
            params: { q: "AI" },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("articles")
        assert json["articles"].length >= 1

        # Should find tc_article_1 which has "AI" in title
        article_ids = json["articles"].map { |a| a["id"] }
        assert_includes article_ids, @tc_article_1.id
      end

      test "search returns articles with truncated content preview" do
        get search_api_v1_articles_url,
            params: { q: "funding" },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        article = json["articles"].first
        # Content should be truncated to 200 characters
        assert article["content"].length <= 201 # 200 chars + possible ellipsis
      end

      test "search returns correct article structure" do
        get search_api_v1_articles_url,
            params: { q: "Ruby" },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        if json["articles"].any?
          article = json["articles"].first

          assert article.key?("id")
          assert article.key?("title")
          assert article.key?("content")
          assert article.key?("url")
          assert article.key?("published_at")
          assert article.key?("feed")
          assert article.key?("state")
        end
      end

      test "search only returns articles from user subscriptions" do
        get search_api_v1_articles_url,
            params: { q: "Ruby" },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        # Alice is not subscribed to ruby_weekly, so should not find ruby_article_1
        article_ids = json["articles"].map { |a| a["id"] }
        assert_not_includes article_ids, @ruby_article_1.id
      end

      test "search requires authentication" do
        get search_api_v1_articles_url,
            params: { q: "test" },
            as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)
        assert_equal "Unauthorized", json["error"]
      end

      test "search returns empty array when no matches found" do
        get search_api_v1_articles_url,
            params: { q: "nonexistentquery123456" },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("articles")
        assert_equal 0, json["articles"].length
      end

      test "search limits results to 50" do
        # Create many articles to test limit
        51.times do |i|
          Article.create!(
            feed: @tech_crunch,
            title: "Search Test Article #{i}",
            content: "searchable content",
            url: "https://example.com/search-#{i}",
            guid: "search_test_#{i}",
            published_at: Time.current
          )
        end

        get search_api_v1_articles_url,
            params: { q: "searchable" },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json["articles"].length <= 50
      end

      # Edge cases and additional scenarios
      test "index handles user with no subscriptions" do
        charlie = users(:charlie)

        get api_v1_articles_url, headers: api_headers(charlie), as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert_equal 0, json["articles"].length
      end

      test "index combines multiple filters" do
        get api_v1_articles_url,
            params: {
              feed_id: @tech_crunch.id,
              filter: "starred"
            },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        json["articles"].each do |article|
          assert_equal @tech_crunch.id, article["feed"]["id"]
          assert_equal true, article["state"]["starred"]
        end
      end

      test "marking article state persists across requests" do
        # Mark as read
        patch mark_read_api_v1_article_url(@tc_article_1),
              params: { read: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :success

        # Fetch article again
        get api_v1_article_url(@tc_article_1),
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal true, json["article"]["state"]["read"]
      end

      test "different users have independent article states" do
        # Alice marks as read
        patch mark_read_api_v1_article_url(@tc_article_1),
              params: { read: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :success

        # Bob's state should be unaffected (bob is also subscribed to tech_crunch)
        get api_v1_article_url(@tc_article_1),
            headers: api_headers(@bob),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)
        # Bob hasn't read it, so state should be default (false)
        assert_equal false, json["article"]["state"]["read"]
      end
    end
  end
end
