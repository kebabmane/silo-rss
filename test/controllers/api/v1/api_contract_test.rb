require "test_helper"

module Api
  module V1
    class ApiContractTest < ActionDispatch::IntegrationTest
      setup do
        @alice = users(:alice)
        @bob = users(:bob)
        @tech_crunch = feeds(:tech_crunch)
        @tc_article_1 = articles(:tc_article_1)
        @hn_article_1 = articles(:hn_article_1)
      end

      # ---------------------------------------------------------------
      # Articles index response contract
      # ---------------------------------------------------------------
      test "articles index response matches expected contract" do
        get api_v1_articles_url, headers: api_headers(@alice), as: :json
        assert_response :success

        json = JSON.parse(response.body)

        # Top-level structure
        assert json.key?("articles"), "Response must have 'articles' key"
        assert json.key?("meta"), "Response must have 'meta' key"
        assert_kind_of Array, json["articles"]
        assert_kind_of Hash, json["meta"]

        # Meta structure
        meta = json["meta"]
        assert meta.key?("total"), "Meta must have 'total'"
        assert meta.key?("limit"), "Meta must have 'limit'"
        assert meta.key?("offset"), "Meta must have 'offset'"
        assert_kind_of Integer, meta["total"]
        assert_kind_of Integer, meta["limit"]
        assert_kind_of Integer, meta["offset"]

        # Article summary structure (if any articles exist)
        if json["articles"].any?
          article = json["articles"].first
          assert_article_summary_contract(article)
        end
      end

      # ---------------------------------------------------------------
      # Article show response contract
      # ---------------------------------------------------------------
      test "article show response matches expected contract" do
        get api_v1_article_url(@tc_article_1), headers: api_headers(@alice), as: :json
        assert_response :success

        json = JSON.parse(response.body)
        assert json.key?("article"), "Response must have 'article' key"

        article_json = json["article"]
        assert_article_detail_contract(article_json)
      end

      # ---------------------------------------------------------------
      # Auth login response contract
      # ---------------------------------------------------------------
      test "auth login success response matches expected contract" do
        post api_v1_auth_login_url,
             params: { email: "alice@example.com", password: "password" },
             as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("user"), "Login response must have 'user'"

        user = json["user"]
        assert user.key?("id"), "User must have 'id'"
        assert user.key?("email"), "User must have 'email'"
        assert user.key?("api_token"), "User must have 'api_token'"
        assert user.key?("api_token_expires_at"), "User must have 'api_token_expires_at'"
        assert_kind_of Integer, user["id"]
        assert_kind_of String, user["email"]
        assert_kind_of String, user["api_token"]
      end

      test "auth login failure response matches expected contract" do
        post api_v1_auth_login_url,
             params: { email: "alice@example.com", password: "wrong" },
             as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)

        assert json.key?("error"), "Error response must have 'error'"
        assert_kind_of String, json["error"]
      end

      # ---------------------------------------------------------------
      # Auth register response contract
      # ---------------------------------------------------------------
      test "auth register success response matches expected contract" do
        post api_v1_auth_register_url,
             params: {
               email: "contract_test@example.com",
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :created
        json = JSON.parse(response.body)

        assert json.key?("user"), "Register response must have 'user'"
        assert json.key?("message"), "Register response must have 'message'"

        user = json["user"]
        assert user.key?("id"), "User must have 'id'"
        assert user.key?("email"), "User must have 'email'"
        assert user.key?("confirmed"), "User must have 'confirmed'"
        assert_kind_of Integer, user["id"]
        assert_kind_of String, user["email"]
        assert_includes [true, false], user["confirmed"]
      end

      # ---------------------------------------------------------------
      # Article state mutation contracts
      # ---------------------------------------------------------------
      test "mark_read response matches state contract" do
        patch mark_read_api_v1_article_url(@tc_article_1),
              params: { read: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("state"), "Response must have 'state' key"
        assert_state_contract(json["state"])
      end

      test "mark_starred response matches state contract" do
        patch mark_starred_api_v1_article_url(@tc_article_1),
              params: { starred: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("state"), "Response must have 'state' key"
        assert_state_contract(json["state"])
      end

      test "mark_archived response matches state contract" do
        patch mark_archived_api_v1_article_url(@tc_article_1),
              params: { archived: true },
              headers: api_headers(@alice),
              as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("state"), "Response must have 'state' key"
        assert_state_contract(json["state"])
      end

      # ---------------------------------------------------------------
      # Unread count response contract
      # ---------------------------------------------------------------
      test "unread_count response matches expected contract" do
        get unread_count_api_v1_articles_url, headers: api_headers(@alice), as: :json
        assert_response :success

        json = JSON.parse(response.body)
        assert json.key?("unread_count"), "Response must have 'unread_count'"
        assert_kind_of Integer, json["unread_count"]
      end

      # ---------------------------------------------------------------
      # Search response contract
      # ---------------------------------------------------------------
      test "search response matches expected contract" do
        get search_api_v1_articles_url,
            params: { q: "AI" },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("articles"), "Search response must have 'articles' key"
        assert_kind_of Array, json["articles"]

        if json["articles"].any?
          article = json["articles"].first
          assert_article_summary_contract(article)
        end
      end

      test "search with empty query returns empty articles array" do
        get search_api_v1_articles_url,
            params: { q: "" },
            headers: api_headers(@alice),
            as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("articles"), "Response must have 'articles' key"
        assert_kind_of Array, json["articles"]
      end

      # ---------------------------------------------------------------
      # Batch update response contract
      # ---------------------------------------------------------------
      test "batch_update response matches expected contract" do
        post batch_update_api_v1_articles_url,
             params: {
               article_ids: [@tc_article_1.id, @hn_article_1.id],
               bulk_action: "mark_read",
               value: true
             },
             headers: api_headers(@alice),
             as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("success"), "Batch update response must have 'success'"
        assert json.key?("updated_count"), "Batch update response must have 'updated_count'"
        assert_equal true, json["success"]
        assert_kind_of Integer, json["updated_count"]
      end

      # ---------------------------------------------------------------
      # Mark all read response contract
      # ---------------------------------------------------------------
      test "mark_all_read response matches expected contract" do
        post mark_all_read_api_v1_articles_url,
             headers: api_headers(@alice),
             as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("success"), "Mark all read response must have 'success'"
        assert json.key?("marked_count"), "Mark all read response must have 'marked_count'"
        assert_equal true, json["success"]
        assert_kind_of Integer, json["marked_count"]
      end

      # ---------------------------------------------------------------
      # Unauthorized response contract
      # ---------------------------------------------------------------
      test "unauthorized response matches expected contract" do
        get api_v1_articles_url, as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)

        assert json.key?("error"), "Unauthorized response must have 'error'"
        assert_kind_of String, json["error"]
      end

      private

      def assert_article_summary_contract(article)
        %w[id title content url published_at feed state].each do |key|
          assert article.key?(key), "Article summary must have '#{key}'"
        end

        assert_kind_of Integer, article["id"]
        assert_kind_of String, article["title"]

        # Feed structure in summary
        feed = article["feed"]
        assert feed.key?("id"), "Feed must have 'id'"
        assert feed.key?("title"), "Feed must have 'title'"
        assert_kind_of Integer, feed["id"]
        assert_kind_of String, feed["title"]

        # State structure
        assert_state_contract(article["state"])
      end

      def assert_article_detail_contract(article)
        %w[id title content url published_at feed state].each do |key|
          assert article.key?(key), "Article detail must have '#{key}'"
        end

        assert_kind_of Integer, article["id"]
        assert_kind_of String, article["title"]

        # Feed structure in detail includes site_url
        feed = article["feed"]
        %w[id title site_url].each do |key|
          assert feed.key?(key), "Detail feed must have '#{key}'"
        end
        assert_kind_of Integer, feed["id"]
        assert_kind_of String, feed["title"]

        # State structure
        assert_state_contract(article["state"])
      end

      def assert_state_contract(state)
        %w[read starred archived].each do |key|
          assert state.key?(key), "State must have '#{key}'"
          assert_includes [true, false], state[key], "State '#{key}' must be a boolean"
        end
      end
    end
  end
end
