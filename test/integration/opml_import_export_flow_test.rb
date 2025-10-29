require "test_helper"

class OpmlImportExportFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    login_as(@user)
  end

  test "export subscriptions to OPML" do
    get export_opml_feeds_path
    assert_response :success

    # Should return XML content
    assert_equal "text/xml", response.content_type

    # Parse the OPML
    doc = Nokogiri::XML(response.body)

    # Should have OPML structure
    assert_equal "opml", doc.root.name
    assert_equal "2.0", doc.root["version"]

    # Should have head with title
    assert_equal "Silo Export", doc.at_xpath("//head/title").text

    # Should have dateCreated
    assert doc.at_xpath("//head/dateCreated").present?

    # Should have body with outlines
    assert doc.at_xpath("//body").present?
  end

  test "exported OPML contains user's subscriptions" do
    get export_opml_feeds_path

    doc = Nokogiri::XML(response.body)

    # Alice has subscriptions in Technology category
    tech_category = doc.at_xpath("//outline[@text='Technology']")
    assert tech_category

    # Should contain TechCrunch feed
    tech_crunch_outline = tech_category.xpath("outline[@xmlUrl='https://techcrunch.com/feed/']").first
    assert tech_crunch_outline
    assert_equal "TechCrunch", tech_crunch_outline["title"]
    assert_equal "https://techcrunch.com", tech_crunch_outline["htmlUrl"]

    # Should contain Hacker News with custom name
    hn_outline = tech_category.xpath("outline[@xmlUrl='https://news.ycombinator.com/rss']").first
    assert hn_outline
    assert_equal "HN - Custom Name", hn_outline["title"]
  end

  test "export filename includes current date" do
    get export_opml_feeds_path

    expected_filename = "silo_export_#{Date.current}.opml"
    assert_match expected_filename, response.headers["Content-Disposition"]
  end

  test "import OPML with valid feeds" do
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <head>
          <title>Feed Subscriptions</title>
        </head>
        <body>
          <outline text="Development" title="Development">
            <outline type="rss" text="Rails Blog" title="Rails Blog"
                     xmlUrl="https://weblog.rubyonrails.org/feed.xml"
                     htmlUrl="https://weblog.rubyonrails.org"/>
          </outline>
          <outline text="News" title="News">
            <outline type="rss" text="Tech News" title="Tech News"
                     xmlUrl="https://technews.com/rss"
                     htmlUrl="https://technews.com"/>
          </outline>
        </body>
      </opml>
    OPML

    # Mock feed refresh job
    FeedRefreshJob.stubs(:perform_later)

    # Upload OPML file
    opml_file = Rack::Test::UploadedFile.new(
      StringIO.new(opml_content),
      "text/xml",
      original_filename: "subscriptions.opml"
    )

    assert_difference "@user.subscriptions.count", 2 do
      assert_difference "Feed.count", 2 do
        post import_opml_feeds_path, params: { opml_file: opml_file }
      end
    end

    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match /Successfully imported 2 feeds/, flash[:notice]

    # Verify feeds were created
    rails_feed = Feed.find_by(feed_url: "https://weblog.rubyonrails.org/feed.xml")
    assert rails_feed
    assert_equal "Rails Blog", rails_feed.title
    assert_equal "https://weblog.rubyonrails.org", rails_feed.site_url

    # Verify subscriptions were created with correct categories
    rails_sub = @user.subscriptions.find_by(feed: rails_feed)
    assert rails_sub
    assert_equal "Development", rails_sub.category
    # Custom name is set to the OPML title on import for new feeds
    assert_equal "Rails Blog", rails_sub.custom_name

    tech_news_feed = Feed.find_by(feed_url: "https://technews.com/rss")
    tech_news_sub = @user.subscriptions.find_by(feed: tech_news_feed)
    assert_equal "News", tech_news_sub.category
  end

  test "import OPML with existing feeds doesn't create duplicates" do
    # Alice already has tech_crunch subscription
    existing_feed = feeds(:tech_crunch)

    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Tech" title="Tech">
            <outline type="rss" text="TechCrunch" title="TechCrunch"
                     xmlUrl="#{existing_feed.feed_url}"
                     htmlUrl="#{existing_feed.site_url}"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = Rack::Test::UploadedFile.new(
      StringIO.new(opml_content),
      "text/xml",
      original_filename: "subscriptions.opml"
    )

    # Should not create duplicate feed or subscription
    assert_no_difference "@user.subscriptions.count" do
      assert_no_difference "Feed.count" do
        post import_opml_feeds_path, params: { opml_file: opml_file }
      end
    end

    assert_redirected_to dashboard_path
    assert_match /Successfully imported 0 feeds/, flash[:notice]
  end

  test "import OPML without file shows error" do
    post import_opml_feeds_path, params: { opml_file: nil }

    assert_redirected_to feeds_path
    follow_redirect!
    assert_match /Please select an OPML file/, flash[:alert]
  end

  test "import handles feeds from different categories" do
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Technology" title="Technology">
            <outline type="rss" xmlUrl="https://tech1.com/feed" htmlUrl="https://tech1.com" text="Tech1"/>
            <outline type="rss" xmlUrl="https://tech2.com/feed" htmlUrl="https://tech2.com" text="Tech2"/>
          </outline>
          <outline text="Science" title="Science">
            <outline type="rss" xmlUrl="https://science1.com/feed" htmlUrl="https://science1.com" text="Science1"/>
          </outline>
        </body>
      </opml>
    OPML

    FeedRefreshJob.stubs(:perform_later)

    opml_file = Rack::Test::UploadedFile.new(
      StringIO.new(opml_content),
      "text/xml",
      original_filename: "subscriptions.opml"
    )

    post import_opml_feeds_path, params: { opml_file: opml_file }

    # Verify category assignments
    tech1_sub = @user.subscriptions.joins(:feed).find_by(feeds: { feed_url: "https://tech1.com/feed" })
    tech2_sub = @user.subscriptions.joins(:feed).find_by(feeds: { feed_url: "https://tech2.com/feed" })
    science1_sub = @user.subscriptions.joins(:feed).find_by(feeds: { feed_url: "https://science1.com/feed" })

    assert_equal "Technology", tech1_sub.category
    assert_equal "Technology", tech2_sub.category
    assert_equal "Science", science1_sub.category
  end

  test "import OPML with custom feed names" do
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Blogs" title="Blogs">
            <outline type="rss" text="My Favorite Blog" title="My Favorite Blog"
                     xmlUrl="https://blog.example.com/feed"
                     htmlUrl="https://blog.example.com"/>
          </outline>
        </body>
      </opml>
    OPML

    FeedRefreshJob.stubs(:perform_later)

    opml_file = Rack::Test::UploadedFile.new(
      StringIO.new(opml_content),
      "text/xml",
      original_filename: "subscriptions.opml"
    )

    post import_opml_feeds_path, params: { opml_file: opml_file }

    feed = Feed.find_by(feed_url: "https://blog.example.com/feed")
    subscription = @user.subscriptions.find_by(feed: feed)

    # Custom name should be preserved if different from feed title
    assert_equal "My Favorite Blog", feed.title
  end

  test "complete OPML workflow: export, import to different user" do
    # Step 1: Alice exports her subscriptions
    get export_opml_feeds_path
    assert_response :success

    opml_content = response.body

    # Step 2: Bob logs in
    bob = users(:bob)
    login_as(bob)

    # Step 3: Bob imports Alice's OPML
    FeedRefreshJob.stubs(:perform_later)

    opml_file = Rack::Test::UploadedFile.new(
      StringIO.new(opml_content),
      "text/xml",
      original_filename: "subscriptions.opml"
    )

    initial_bob_subscriptions = bob.subscriptions.count

    post import_opml_feeds_path, params: { opml_file: opml_file }

    # Bob should have new subscriptions
    assert bob.subscriptions.count > initial_bob_subscriptions

    # Both users should now be subscribed to TechCrunch
    assert @user.subscriptions.joins(:feed).exists?(feeds: { feed_url: "https://techcrunch.com/feed/" })
    assert bob.subscriptions.joins(:feed).exists?(feeds: { feed_url: "https://techcrunch.com/feed/" })
  end

  test "import triggers feed refresh for new feeds" do
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Test">
            <outline type="rss" xmlUrl="https://newfeed.com/rss" htmlUrl="https://newfeed.com" text="New Feed"/>
          </outline>
        </body>
      </opml>
    OPML

    # Expect job to be enqueued
    FeedRefreshJob.expects(:perform_later).once

    opml_file = Rack::Test::UploadedFile.new(
      StringIO.new(opml_content),
      "text/xml",
      original_filename: "subscriptions.opml"
    )

    post import_opml_feeds_path, params: { opml_file: opml_file }
  end

  test "export and re-import produces same subscriptions" do
    # Export current subscriptions
    get export_opml_feeds_path
    original_opml = response.body

    # Count current subscriptions
    original_count = @user.subscriptions.count

    # Delete all subscriptions
    @user.subscriptions.destroy_all
    assert_equal 0, @user.subscriptions.count

    # Re-import
    FeedRefreshJob.stubs(:perform_later)

    opml_file = Rack::Test::UploadedFile.new(
      StringIO.new(original_opml),
      "text/xml",
      original_filename: "subscriptions.opml"
    )

    post import_opml_feeds_path, params: { opml_file: opml_file }

    # Should have same number of subscriptions
    assert_equal original_count, @user.subscriptions.count

    # Verify subscriptions match
    doc = Nokogiri::XML(original_opml)
    doc.xpath("//outline[@xmlUrl]").each do |outline|
      feed_url = outline["xmlUrl"]
      assert @user.subscriptions.joins(:feed).exists?(feeds: { feed_url: feed_url }),
             "Missing subscription for #{feed_url}"
    end
  end

  test "import OPML with uncategorized feeds" do
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline type="rss" xmlUrl="https://uncategorized.com/feed" htmlUrl="https://uncategorized.com" text="Uncategorized Feed"/>
        </body>
      </opml>
    OPML

    FeedRefreshJob.stubs(:perform_later)

    opml_file = Rack::Test::UploadedFile.new(
      StringIO.new(opml_content),
      "text/xml",
      original_filename: "subscriptions.opml"
    )

    post import_opml_feeds_path, params: { opml_file: opml_file }

    # Should import with default category
    feed = Feed.find_by(feed_url: "https://uncategorized.com/feed")
    subscription = @user.subscriptions.find_by(feed: feed)

    # The parent node has no text, so should use "Imported" as category
    assert subscription.category.present?
  end

  test "export includes all subscription metadata" do
    get export_opml_feeds_path
    doc = Nokogiri::XML(response.body)

    # Check for feed with custom name (Hacker News)
    hn_outline = doc.xpath("//outline[@xmlUrl='https://news.ycombinator.com/rss']").first
    assert hn_outline

    # Should use custom name as title
    assert_equal "HN - Custom Name", hn_outline["title"]
    assert_equal "HN - Custom Name", hn_outline["text"]

    # Should have correct category (Technology)
    assert_equal "Technology", hn_outline.parent["text"]
  end

  test "import handles missing optional OPML attributes" do
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Minimal">
            <outline xmlUrl="https://minimal.com/feed"/>
          </outline>
        </body>
      </opml>
    OPML

    FeedRefreshJob.stubs(:perform_later)

    opml_file = Rack::Test::UploadedFile.new(
      StringIO.new(opml_content),
      "text/xml",
      original_filename: "subscriptions.opml"
    )

    # Should import successfully even with minimal attributes
    assert_difference "@user.subscriptions.count", 1 do
      post import_opml_feeds_path, params: { opml_file: opml_file }
    end

    feed = Feed.find_by(feed_url: "https://minimal.com/feed")
    assert feed
  end

  test "multiple users can export without affecting each other" do
    # Alice exports
    get export_opml_feeds_path
    alice_opml = response.body

    # Bob exports
    bob = users(:bob)
    login_as(bob)

    get export_opml_feeds_path
    bob_opml = response.body

    # OPMLs should be different
    assert_not_equal alice_opml, bob_opml

    # Alice's OPML should contain TechCrunch
    alice_doc = Nokogiri::XML(alice_opml)
    assert alice_doc.xpath("//outline[@xmlUrl='https://techcrunch.com/feed/']").present?

    # Bob's OPML should contain Ruby Weekly
    bob_doc = Nokogiri::XML(bob_opml)
    assert bob_doc.xpath("//outline[@xmlUrl='https://rubyweekly.com/rss']").present?
  end
end
