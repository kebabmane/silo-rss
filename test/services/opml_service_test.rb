require "test_helper"

class OpmlServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Export tests
  test "export generates valid OPML XML" do
    user = users(:alice)

    opml = OpmlService.export(user)

    assert opml.present?
    assert_includes opml, '<?xml version="1.0" encoding="UTF-8"?>'
    assert_includes opml, '<opml version="2.0">'
  end

  test "export includes OPML header with title and date" do
    user = users(:alice)

    freeze_time do
      opml = OpmlService.export(user)

      assert_includes opml, "<title>Silo Export</title>"
      assert_includes opml, "<dateCreated>#{Time.current.rfc2822}</dateCreated>"
    end
  end

  test "export groups subscriptions by category" do
    user = users(:alice)

    opml = OpmlService.export(user)
    doc = Nokogiri::XML(opml)

    # Alice has 2 subscriptions in Technology category
    technology_outline = doc.at_xpath('//outline[@text="Technology"]')
    assert technology_outline.present?

    feed_outlines = technology_outline.xpath('outline[@type="rss"]')
    assert_equal 2, feed_outlines.count
  end

  test "export includes feed details in outline elements" do
    user = users(:alice)

    opml = OpmlService.export(user)
    doc = Nokogiri::XML(opml)

    # Find TechCrunch feed outline
    tc_outline = doc.at_xpath('//outline[@xmlUrl="https://techcrunch.com/feed/"]')

    assert tc_outline.present?
    assert_equal "rss", tc_outline["type"]
    assert_equal "TechCrunch", tc_outline["text"]
    assert_equal "TechCrunch", tc_outline["title"]
    assert_equal "https://techcrunch.com/feed/", tc_outline["xmlUrl"]
    assert_equal "https://techcrunch.com", tc_outline["htmlUrl"]
  end

  test "export uses custom_name when available" do
    user = users(:alice)

    opml = OpmlService.export(user)
    doc = Nokogiri::XML(opml)

    # Alice has custom name for Hacker News subscription
    hn_outline = doc.at_xpath('//outline[@xmlUrl="https://news.ycombinator.com/rss"]')

    assert_equal "HN - Custom Name", hn_outline["text"]
    assert_equal "HN - Custom Name", hn_outline["title"]
  end

  test "export uses display_name from subscription" do
    user = users(:alice)
    subscription = subscriptions(:alice_tech_crunch)

    # display_name should return feed.title when custom_name is nil
    assert_equal "TechCrunch", subscription.display_name

    opml = OpmlService.export(user)
    doc = Nokogiri::XML(opml)

    tc_outline = doc.at_xpath('//outline[@xmlUrl="https://techcrunch.com/feed/"]')
    assert_equal "TechCrunch", tc_outline["text"]
  end

  test "export handles multiple categories" do
    user = users(:bob)

    opml = OpmlService.export(user)
    doc = Nokogiri::XML(opml)

    # Bob has subscriptions in Programming and News categories
    programming_outline = doc.at_xpath('//outline[@text="Programming"]')
    news_outline = doc.at_xpath('//outline[@text="News"]')

    assert programming_outline.present?
    assert news_outline.present?
  end

  test "export handles user with no subscriptions" do
    user = users(:charlie)

    opml = OpmlService.export(user)

    assert opml.present?
    assert_includes opml, '<opml version="2.0">'

    doc = Nokogiri::XML(opml)
    body = doc.at_xpath("//body")

    # Body should exist but be empty
    assert body.present?
    assert_equal 0, body.xpath("outline").count
  end

  test "export generates well-formed XML" do
    user = users(:alice)

    opml = OpmlService.export(user)
    doc = Nokogiri::XML(opml)

    # Check that XML is valid
    assert_empty doc.errors
  end

  test "export includes all user subscriptions" do
    user = users(:alice)

    opml = OpmlService.export(user)
    doc = Nokogiri::XML(opml)

    feed_outlines = doc.xpath('//outline[@type="rss"]')

    assert_equal user.subscriptions.count, feed_outlines.count
  end

  # Import tests
  test "import creates subscriptions from OPML file" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <head>
          <title>Feed Export</title>
        </head>
        <body>
          <outline text="Technology" title="Technology">
            <outline type="rss" text="TechCrunch" title="TechCrunch"
                     xmlUrl="https://techcrunch.com/feed/"
                     htmlUrl="https://techcrunch.com"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)

    assert_difference "user.subscriptions.count", 1 do
      OpmlService.import(user, opml_file)
    end
  end

  test "import returns count of imported feeds" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Tech">
            <outline type="rss" text="Feed 1" xmlUrl="https://example.com/feed1.xml"/>
            <outline type="rss" text="Feed 2" xmlUrl="https://example.com/feed2.xml"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)

    count = OpmlService.import(user, opml_file)

    assert_equal 2, count
  end

  test "import creates feeds that don't exist" do
    user = users(:charlie)
    new_feed_url = "https://newsite.com/feed.xml"
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="News">
            <outline type="rss" text="New Site" title="New Site"
                     xmlUrl="#{new_feed_url}"
                     htmlUrl="https://newsite.com"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)

    assert_difference "Feed.count", 1 do
      OpmlService.import(user, opml_file)
    end

    feed = Feed.find_by(feed_url: new_feed_url)
    assert feed.present?
    assert_equal "New Site", feed.title
    assert_equal "https://newsite.com", feed.site_url
  end

  test "import reuses existing feeds" do
    user = users(:charlie)
    existing_feed = feeds(:tech_crunch)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Tech">
            <outline type="rss" text="TechCrunch"
                     xmlUrl="#{existing_feed.feed_url}"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)

    assert_no_difference "Feed.count" do
      OpmlService.import(user, opml_file)
    end

    # But should create subscription
    assert user.subscriptions.exists?(feed: existing_feed)
  end

  test "import sets category from parent outline" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Programming" title="Programming">
            <outline type="rss" text="Ruby Blog" xmlUrl="https://example.com/ruby.xml"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)
    OpmlService.import(user, opml_file)

    subscription = user.subscriptions.last
    assert_equal "Programming", subscription.category
  end

  test "import uses parent title as category when text is missing" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline title="Development">
            <outline type="rss" text="Dev Blog" xmlUrl="https://example.com/dev.xml"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)
    OpmlService.import(user, opml_file)

    subscription = user.subscriptions.last
    assert_equal "Development", subscription.category
  end

  test "import defaults to Imported category when parent has no text or title" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline>
            <outline type="rss" text="Blog" xmlUrl="https://example.com/blog.xml"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)
    OpmlService.import(user, opml_file)

    subscription = user.subscriptions.last
    assert_equal "Imported", subscription.category
  end

  test "import sets custom_name from outline text" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Tech">
            <outline type="rss" text="My Custom Feed Name"
                     xmlUrl="https://example.com/feed.xml"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)
    OpmlService.import(user, opml_file)

    subscription = user.subscriptions.last
    assert_equal "My Custom Feed Name", subscription.custom_name
  end

  test "import uses outline title when text is missing" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Tech">
            <outline type="rss" title="Feed Title"
                     xmlUrl="https://example.com/feed.xml"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)
    OpmlService.import(user, opml_file)

    subscription = user.subscriptions.last
    assert_equal "Feed Title", subscription.custom_name
  end

  test "import does not set custom_name when it matches feed title" do
    user = users(:charlie)
    feed = feeds(:tech_crunch)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Tech">
            <outline type="rss" text="#{feed.title}"
                     xmlUrl="#{feed.feed_url}"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)
    OpmlService.import(user, opml_file)

    subscription = user.subscriptions.find_by(feed: feed)
    assert_nil subscription.custom_name
  end

  test "import queues FeedRefreshJob for each imported feed" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Tech">
            <outline type="rss" text="Feed 1" xmlUrl="https://example.com/feed1.xml"/>
            <outline type="rss" text="Feed 2" xmlUrl="https://example.com/feed2.xml"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)

    assert_enqueued_jobs 2, only: FeedRefreshJob do
      OpmlService.import(user, opml_file)
    end
  end

  test "import does not create duplicate subscriptions" do
    user = users(:alice)
    existing_subscription = subscriptions(:alice_tech_crunch)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Tech">
            <outline type="rss" text="TechCrunch"
                     xmlUrl="#{existing_subscription.feed.feed_url}"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)

    assert_no_difference "user.subscriptions.count" do
      count = OpmlService.import(user, opml_file)
      assert_equal 0, count
    end
  end

  test "import handles feeds without categories (flat structure)" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline type="rss" text="Uncategorized Feed"
                   xmlUrl="https://example.com/feed.xml"/>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)
    OpmlService.import(user, opml_file)

    subscription = user.subscriptions.last
    assert_equal "Imported", subscription.category
  end

  test "import handles multiple feeds in same category" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Technology">
            <outline type="rss" text="Feed 1" xmlUrl="https://example.com/feed1.xml"/>
            <outline type="rss" text="Feed 2" xmlUrl="https://example.com/feed2.xml"/>
            <outline type="rss" text="Feed 3" xmlUrl="https://example.com/feed3.xml"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)

    assert_difference "user.subscriptions.count", 3 do
      OpmlService.import(user, opml_file)
    end

    technology_subs = user.subscriptions.where(category: "Technology")
    assert_equal 3, technology_subs.count
  end

  # Error handling tests
  test "import handles invalid XML gracefully" do
    user = users(:charlie)
    invalid_opml = "This is not valid XML at all"
    opml_file = StringIO.new(invalid_opml)

    # Should not raise error
    count = OpmlService.import(user, opml_file)

    assert_equal 0, count
  end

  test "import logs error for failed feed import" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Tech">
            <outline type="rss" text="Feed" xmlUrl="https://example.com/feed.xml"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)

    # Mock feed creation to fail
    Feed.stubs(:find_by).with(feed_url: "https://example.com/feed.xml").returns(nil)
    Feed.stubs(:create!).raises(ActiveRecord::RecordInvalid.new(Feed.new))

    Rails.logger.expects(:error).with(includes("Failed to import feed"))

    count = OpmlService.import(user, opml_file)

    assert_equal 0, count
  end

  test "import continues on individual feed failure" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Tech">
            <outline type="rss" text="Good Feed" xmlUrl="https://example.com/good.xml"/>
            <outline type="rss" text="Bad Feed" xmlUrl="https://example.com/bad.xml"/>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)

    # Mock only the "bad" feed to fail
    good_feed = Feed.create!(feed_url: "https://example.com/good.xml", title: "Good Feed")

    Feed.stubs(:find_by).with(feed_url: "https://example.com/good.xml").returns(nil)
    Feed.stubs(:create!).with do |args|
      args[:feed_url] == "https://example.com/good.xml"
    end.returns(good_feed)

    Feed.stubs(:find_by).with(feed_url: "https://example.com/bad.xml").returns(nil)
    Feed.stubs(:create!).with do |args|
      args[:feed_url] == "https://example.com/bad.xml"
    end.raises(StandardError.new("Creation failed"))

    # Should import the good feed despite bad feed failing
    count = OpmlService.import(user, opml_file)

    # Only the good feed should be imported
    assert_equal 1, count
  end

  test "import handles empty OPML file" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <head>
          <title>Empty Export</title>
        </head>
        <body>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)

    count = OpmlService.import(user, opml_file)

    assert_equal 0, count
  end

  test "import handles OPML with nested categories" do
    user = users(:charlie)
    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <body>
          <outline text="Technology">
            <outline text="Programming">
              <outline type="rss" text="Ruby Blog" xmlUrl="https://example.com/ruby.xml"/>
            </outline>
          </outline>
        </body>
      </opml>
    OPML

    opml_file = StringIO.new(opml_content)
    OpmlService.import(user, opml_file)

    subscription = user.subscriptions.last
    # Should use immediate parent category
    assert_equal "Programming", subscription.category
  end

  # Export/Import round-trip test
  test "export and import round-trip preserves subscriptions" do
    user_export = users(:alice)
    user_import = users(:charlie)

    # Export Alice's subscriptions
    opml = OpmlService.export(user_export)

    # Import into Charlie's account
    opml_file = StringIO.new(opml)
    count = OpmlService.import(user_import, opml_file)

    # Should import all of Alice's subscriptions
    assert_equal user_export.subscriptions.count, count

    # Charlie should now have same feeds as Alice
    alice_feed_urls = user_export.subscriptions.map { |s| s.feed.feed_url }.sort
    charlie_feed_urls = user_import.subscriptions.map { |s| s.feed.feed_url }.sort

    assert_equal alice_feed_urls, charlie_feed_urls
  end

  test "export and import preserves categories" do
    user_export = users(:alice)
    user_import = users(:charlie)

    opml = OpmlService.export(user_export)
    opml_file = StringIO.new(opml)
    OpmlService.import(user_import, opml_file)

    # Check that categories are preserved
    alice_categories = user_export.subscriptions.pluck(:category).uniq.sort
    charlie_categories = user_import.subscriptions.pluck(:category).uniq.sort

    assert_equal alice_categories, charlie_categories
  end

  test "export and import preserves custom names" do
    user_export = users(:alice)
    user_import = users(:charlie)

    # Alice has a custom name for Hacker News
    hn_subscription = subscriptions(:alice_hacker_news)
    assert_equal "HN - Custom Name", hn_subscription.custom_name

    opml = OpmlService.export(user_export)
    opml_file = StringIO.new(opml)
    OpmlService.import(user_import, opml_file)

    # Find Charlie's HN subscription
    hn_feed = feeds(:hacker_news)
    charlie_hn_sub = user_import.subscriptions.find_by(feed: hn_feed)

    assert_equal "HN - Custom Name", charlie_hn_sub.custom_name
  end
end
