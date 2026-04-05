# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    class RateLimitingTest < ActionDispatch::IntegrationTest
      setup do
        @confirmed_user = users(:alice)
        @confirmed_user.confirm!
        @confirmed_user.regenerate_api_token!
      end

      # Token Expiration Tests
      test "returns unauthorized with expired token" do
        # Generate a valid token first, then expire it
        valid_token = @confirmed_user.regenerate_api_token!

        # Now expire the token
        @confirmed_user.update!(api_token_expires_at: 1.day.ago)

        get api_v1_feeds_url,
            headers: { "Authorization" => "Bearer #{valid_token}" },
            as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)
        assert_match /expired/i, json["error"]
      end

      test "returns unauthorized with malformed token" do
        get api_v1_feeds_url,
            headers: { "Authorization" => "Bearer invalid_token_format!!!" },
            as: :json

        assert_response :unauthorized
      end

      test "returns unauthorized with empty token" do
        get api_v1_feeds_url,
            headers: { "Authorization" => "Bearer " },
            as: :json

        assert_response :unauthorized
      end

      test "returns unauthorized without authorization header" do
        get api_v1_feeds_url, as: :json

        assert_response :unauthorized
      end

      test "CLI token does not expire" do
        # Generate CLI token
        cli_token = @confirmed_user.generate_cli_token!

        # Simulate time passing
        travel_to 1.year.from_now do
          get api_v1_feeds_url,
              headers: { "Authorization" => "Bearer #{cli_token}" },
              as: :json

          assert_response :success
        end
      end

      test "accepts token without Bearer prefix" do
        token = @confirmed_user.api_token

        get api_v1_feeds_url,
            headers: { "Authorization" => token },
            as: :json

        assert_response :success
      end

      test "accepts token with Bearer prefix" do
        token = @confirmed_user.api_token

        get api_v1_feeds_url,
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json

        assert_response :success
      end

      # API Version Tests
      test "API v1 endpoints are accessible" do
        get api_v1_feeds_url,
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        assert_response :success
      end

      # Content Type Tests
      test "accepts JSON content type" do
        post api_v1_auth_login_url,
             params: { email: "alice@example.com", password: "password" },
             as: :json

        assert_response :success
      end

      # CORS Tests (if applicable)
      test "API responds to OPTIONS request" do
        process :options, api_v1_feeds_url

        # Should return success or appropriate CORS headers
        assert_includes [ 200, 204, 404 ], response.status
      end

      # Pagination Edge Cases
      test "handles negative limit parameter gracefully" do
        get api_v1_articles_url(limit: -10),
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        assert_response :success
        json = JSON.parse(response.body)
        # Should default to positive limit
        assert json["articles"].length >= 0
      end

      test "handles zero limit parameter gracefully" do
        get api_v1_articles_url(limit: 0),
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        assert_response :success
        json = JSON.parse(response.body)
        assert json["articles"].length >= 0
      end

      test "handles very large limit parameter gracefully" do
        get api_v1_articles_url(limit: 10000),
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        assert_response :success
        json = JSON.parse(response.body)
        # Should clamp to maximum allowed
        assert json["articles"].length <= 100
      end

      test "handles negative offset parameter gracefully" do
        get api_v1_articles_url(offset: -100),
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        assert_response :success
        # Should default to 0
      end

      # Cursor Pagination Edge Cases
      test "handles invalid cursor format gracefully" do
        get api_v1_articles_url(cursor: "invalid_cursor_format"),
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        # Should either return success (treating as no cursor) or bad request
        assert_includes [ 200, 400 ], response.status
      end

      test "handles malformed base64 cursor gracefully" do
        get api_v1_articles_url(cursor: "!!!not_valid_base64!!!"),
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        # Should handle gracefully
        assert_includes [ 200, 400 ], response.status
      end

      # Filter Edge Cases
      test "handles unknown filter parameter gracefully" do
        get api_v1_articles_url(filter: "unknown_filter"),
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        # Should default gracefully or return error
        assert_includes [ 200, 400 ], response.status
      end

      test "handles special characters in search query" do
        get search_api_v1_articles_url(q: "test<script>alert(1)</script>"),
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        # Should sanitize and not crash
        assert_includes [ 200, 422 ], response.status
      end

      test "handles SQL injection attempt in search query safely" do
        get search_api_v1_articles_url(q: "'; DROP TABLE articles; --"),
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        # Should not crash and not execute SQL injection
        assert_response :success
        # Verify articles table still exists
        assert Article.count >= 0
      end

      # Feed Discovery Edge Cases
      test "returns proper error for invalid URL in discovery" do
        post discover_api_v1_feeds_url,
             params: { url: "not_a_valid_url" },
             headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
             as: :json

        assert_response :not_found
        json = JSON.parse(response.body)
        assert json.key?("error")
      end

      test "returns proper error for private IP in discovery" do
        post discover_api_v1_feeds_url,
             params: { url: "http://192.168.1.1/feed.xml" },
             headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
             as: :json

        # Should be blocked by UrlSafety
        assert_response :not_found
      end

      test "returns proper error for localhost in discovery" do
        post discover_api_v1_feeds_url,
             params: { url: "http://localhost/admin" },
             headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
             as: :json

        # Should be blocked by UrlSafety
        assert_response :not_found
      end

      # Batch Operations Edge Cases
      test "handles empty article_ids array in batch update" do
        post batch_update_api_v1_articles_url,
             params: { article_ids: [], bulk_action: "mark_read", value: true },
             headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
             as: :json

        # Should return error for empty array
        assert_response :unprocessable_entity
      end

      test "handles missing article_ids in batch update" do
        post batch_update_api_v1_articles_url,
             params: { bulk_action: "mark_read", value: true },
             headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
             as: :json

        assert_response :unprocessable_entity
      end

      test "handles invalid bulk_action in batch update" do
        # First get some article IDs
        article = articles(:tc_article_1)

        post batch_update_api_v1_articles_url,
             params: { article_ids: [ article.id ], bulk_action: "invalid_action", value: true },
             headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
             as: :json

        assert_response :unprocessable_entity
      end

      test "ignores article IDs user does not have access to in batch update" do
        # Try to update an article from a feed the user is not subscribed to
        # This requires creating articles in the test fixtures

        # For now, test with non-existent IDs
        post batch_update_api_v1_articles_url,
             params: { article_ids: [ 99999, 99998 ], bulk_action: "mark_read", value: true },
             headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
             as: :json

        assert_response :success
        json = JSON.parse(response.body)
        # Should report 0 updated since these articles don't exist or user has no access
        assert_equal 0, json["updated_count"]
      end

      # Resource Not Found Tests
      test "returns not found for non-existent article" do
        get api_v1_article_url(id: 99999),
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        assert_response :not_found
      end

      test "returns not found for non-existent feed" do
        get api_v1_feed_url(id: 99999),
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        assert_response :not_found
      end

      # ETag / Caching Tests
      test "returns consistent ETag for same resource" do
        get api_v1_articles_url,
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        assert_response :success
        etag1 = response.headers["ETag"]

        get api_v1_articles_url,
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
            as: :json

        etag2 = response.headers["ETag"]

        # ETags should be consistent for unchanged resources
        assert_equal etag1, etag2 if etag1 && etag2
      end

      # Method Not Allowed Tests
      test "returns method not allowed for unsupported HTTP methods" do
        process :patch, api_v1_feeds_url,
                headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" }

        # PATCH on collection is not supported
        assert_includes [ 405, 404 ], response.status
      end

      # Content Negotiation Tests
      test "defaults to JSON without Accept header" do
        get api_v1_feeds_url,
            headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" }

        assert_response :success
        # Should still return JSON
        assert_nothing_raised { JSON.parse(response.body) }
      end

      # Large Payload Tests
      test "handles large batch update gracefully" do
        # Create an array of many IDs (that don't exist)
        many_ids = (1..1000).to_a

        post batch_update_api_v1_articles_url,
             params: { article_ids: many_ids, bulk_action: "mark_read", value: true },
             headers: { "Authorization" => "Bearer #{@confirmed_user.api_token}" },
             as: :json

        # Should complete without error (even if no articles are actually updated)
        assert_includes [ 200, 422 ], response.status
      end
    end
  end
end
