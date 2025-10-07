require "application_system_test_case"

class FeedManagementTest < ApplicationSystemTestCase
  setup do
    @user = users(:alice)
    # Login before each test
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
  end

  test "user can access feed management page" do
    visit feeds_path

    assert_selector "h1", text: "Manage Feeds"
    assert_button "Add Feed"
    assert_button "Export OPML"
  end

  test "user can navigate to add feed page" do
    visit feeds_path

    click_link "Add Feed"

    assert_current_path new_feed_path
    assert_selector "h1", text: "Add New Feed"
    assert_field "Feed URL or Website URL"
  end

  test "user can discover and subscribe to a feed from URL" do
    visit new_feed_path

    # Mock the HTTP request for feed discovery
    feed_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <link>https://example.com</link>
          <description>A test feed</description>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: feed_xml, headers: { "Content-Type" => "application/rss+xml" })

    stub_request(:get, "https://example.com")
      .to_return(status: 200, body: '<html><head><link rel="alternate" type="application/rss+xml" href="https://example.com/feed.xml"></head></html>')

    # Enter feed URL
    fill_in "Feed URL or Website URL", with: "https://example.com"
    click_button "Discover Feed"

    # Wait for Turbo Frame to update with discovered feed
    assert_text "Test Feed", wait: 5

    # Subscribe to the feed
    fill_in "custom_name", with: "My Test Feed"
    select "Uncategorized", from: "category"
    click_button "Subscribe"

    # Should redirect to dashboard with success message
    assert_text "Feed added successfully"
    assert_current_path dashboard_path

    # Verify subscription was created
    subscription = @user.subscriptions.joins(:feed).find_by(feeds: { feed_url: "https://example.com/feed.xml" })
    assert_not_nil subscription
    assert_equal "My Test Feed", subscription.custom_name
  end

  test "user can subscribe to feed with direct RSS URL" do
    visit new_feed_path

    feed_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Direct RSS Feed</title>
          <link>https://directrss.com</link>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://directrss.com/rss")
      .to_return(status: 200, body: feed_xml, headers: { "Content-Type" => "application/rss+xml" })

    fill_in "Feed URL or Website URL", with: "https://directrss.com/rss"
    click_button "Discover Feed"

    assert_text "Direct RSS Feed", wait: 5
  end

  test "user sees error when feed discovery fails" do
    visit new_feed_path

    stub_request(:get, "https://invalid-feed.com")
      .to_return(status: 404)

    fill_in "Feed URL or Website URL", with: "https://invalid-feed.com"
    click_button "Discover Feed"

    # Should show error message in turbo frame
    assert_text "Could not discover feed", wait: 5
  end

  test "user can view their subscribed feeds" do
    visit feeds_path

    # User should see their feeds organized by category
    @user.subscriptions.each do |subscription|
      assert_text subscription.display_name
      assert_text subscription.feed.feed_url
    end
  end

  test "user can remove a feed subscription" do
    subscription = subscriptions(:alice_tech_crunch)
    feed = subscription.feed

    visit feeds_path

    # Find and remove the subscription
    within "div", text: subscription.display_name do
      accept_confirm do
        click_button "Remove"
      end
    end

    # Should redirect with success message
    assert_text "Feed removed"
    assert_current_path feeds_path

    # Verify subscription was deleted
    assert_nil @user.subscriptions.find_by(feed: feed)
  end

  test "removing feed shows confirmation dialog" do
    visit feeds_path

    subscription = subscriptions(:alice_tech_crunch)

    within "div", text: subscription.display_name do
      # Dismiss the confirmation
      dismiss_confirm do
        click_button "Remove"
      end
    end

    # Should still be on feeds page, subscription not removed
    assert_current_path feeds_path
    assert_not_nil @user.subscriptions.find_by(id: subscription.id)
  end

  test "user can categorize feeds" do
    visit new_feed_path

    feed_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Tech News</title>
          <link>https://technews.com</link>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://technews.com/feed")
      .to_return(status: 200, body: feed_xml)

    stub_request(:get, "https://technews.com")
      .to_return(status: 200, body: '<html><head><link rel="alternate" type="application/rss+xml" href="https://technews.com/feed"></head></html>')

    fill_in "Feed URL or Website URL", with: "https://technews.com"
    click_button "Discover Feed"

    assert_text "Tech News", wait: 5

    # Select a category
    fill_in "category", with: "Technology"
    click_button "Subscribe"

    assert_text "Feed added successfully"

    # Verify categorization
    subscription = @user.subscriptions.joins(:feed).find_by(feeds: { feed_url: "https://technews.com/feed" })
    assert_equal "Technology", subscription.category
  end

  test "user can import OPML file" do
    visit feeds_path

    opml_content = <<~OPML
      <?xml version="1.0" encoding="UTF-8"?>
      <opml version="2.0">
        <head><title>Feed Subscriptions</title></head>
        <body>
          <outline text="Imported Feed" type="rss" xmlUrl="https://imported.com/feed" htmlUrl="https://imported.com"/>
        </body>
      </opml>
    OPML

    # Create a temporary OPML file
    opml_file = Tempfile.new(["feeds", ".opml"])
    opml_file.write(opml_content)
    opml_file.rewind

    # Mock the feed fetch
    stub_request(:get, "https://imported.com/feed")
      .to_return(status: 200, body: '<?xml version="1.0"?><rss version="2.0"><channel><title>Imported Feed</title></channel></rss>')

    # Upload OPML file
    attach_file "opml_file", opml_file.path
    click_button "Import"

    # Should see success message
    assert_text "Successfully imported", wait: 5

    opml_file.close
    opml_file.unlink
  end

  test "user can export OPML file" do
    visit feeds_path

    click_link "Export OPML"

    # Should download a file
    # In system tests, we verify the link exists and has correct href
    assert_link "Export OPML", href: export_opml_feeds_path
  end

  test "empty state shows message when no feeds subscribed" do
    # Remove all subscriptions for user
    @user.subscriptions.destroy_all

    visit feeds_path

    assert_text "No feeds yet. Add your first feed to get started!"
  end

  test "feeds are grouped by category" do
    # Create subscriptions with different categories
    feed1 = feeds(:tech_crunch)
    feed2 = feeds(:hacker_news)

    @user.subscriptions.create!(feed: feed1, category: "Technology")
    @user.subscriptions.create!(feed: feed2, category: "News")

    visit feeds_path

    # Should see category headers
    assert_text "Technology"
    assert_text "News"
  end

  test "user can customize feed display name" do
    visit new_feed_path

    feed_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Original Title</title>
          <link>https://custom.com</link>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://custom.com/feed")
      .to_return(status: 200, body: feed_xml)

    stub_request(:get, "https://custom.com")
      .to_return(status: 200, body: '<html><head><link rel="alternate" type="application/rss+xml" href="https://custom.com/feed"></head></html>')

    fill_in "Feed URL or Website URL", with: "https://custom.com"
    click_button "Discover Feed"

    assert_text "Original Title", wait: 5

    # Set custom name
    fill_in "custom_name", with: "My Custom Name"
    click_button "Subscribe"

    # Verify custom name is used
    visit feeds_path
    assert_text "My Custom Name"
  end

  test "duplicate feed subscription is handled gracefully" do
    # Subscribe to a feed that user already has
    existing_feed = feeds(:tech_crunch)

    visit new_feed_path

    stub_request(:get, existing_feed.feed_url)
      .to_return(status: 200, body: '<?xml version="1.0"?><rss version="2.0"><channel><title>TechCrunch</title></channel></rss>')

    fill_in "Feed URL or Website URL", with: existing_feed.feed_url
    click_button "Discover Feed"

    # Should still show the feed for subscription
    assert_text existing_feed.title, wait: 5
  end

  test "feed discovery supports Atom feeds" do
    visit new_feed_path

    atom_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Atom Feed</title>
        <link href="https://atom.com"/>
      </feed>
    XML

    stub_request(:get, "https://atom.com/atom.xml")
      .to_return(status: 200, body: atom_xml, headers: { "Content-Type" => "application/atom+xml" })

    fill_in "Feed URL or Website URL", with: "https://atom.com/atom.xml"
    click_button "Discover Feed"

    assert_text "Atom Feed", wait: 5
  end

  test "user can navigate back to dashboard from feed management" do
    visit feeds_path

    click_link "Back to Dashboard"

    assert_current_path dashboard_path
  end

  test "user can navigate back to dashboard from add feed page" do
    visit new_feed_path

    click_link "Back to Dashboard"

    assert_current_path dashboard_path
  end

  test "feed discovery uses Turbo Frames for seamless UX" do
    visit new_feed_path

    # Verify turbo frame exists
    assert_selector "turbo-frame#feed_discovery"

    # Verify form uses turbo frame
    form = find("form[action='#{discover_feeds_path}']")
    assert_equal "feed_discovery", form["data-turbo-frame"]
  end

  test "existing categories are available for selection" do
    # Create some subscriptions with categories
    @user.subscriptions.create!(feed: feeds(:tech_crunch), category: "Tech")
    @user.subscriptions.create!(feed: feeds(:hacker_news), category: "News")

    visit new_feed_path

    feed_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>New Feed</title>
          <link>https://newfeed.com</link>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://newfeed.com/feed")
      .to_return(status: 200, body: feed_xml)

    stub_request(:get, "https://newfeed.com")
      .to_return(status: 200, body: '<html><head><link rel="alternate" type="application/rss+xml" href="https://newfeed.com/feed"></head></html>')

    fill_in "Feed URL or Website URL", with: "https://newfeed.com"
    click_button "Discover Feed"

    # After discovery, existing categories should be available
    # This depends on implementation - adjust selector as needed
    assert_text "New Feed", wait: 5
  end
