require "application_system_test_case"

class UiComprehensiveAuditTest < ApplicationSystemTestCase
  # Audit configuration
  SCREENSHOT_DIR = Rails.root.join("tmp", "screenshots", "ui-audit")
  REPORT_FILE = Rails.root.join("tmp", "screenshots", "ui-audit-report.md")

  # Issues tracking
  @detected_issues = []

  setup do
    FileUtils.mkdir_p(SCREENSHOT_DIR)
    @detected_issues = []
  end

  teardown do
    generate_report
  end

  # ============================================================
  # SCREENSHOT CAPTURE TESTS
  # ============================================================

  test "capture all screens for visual audit" do
    # Create user and feed for realistic screenshots
    user = create_test_user
    feed = create_test_feed
    create_test_articles(feed)
    login_as(user)

    # 1. Dashboard screens
    capture_dashboard_screens

    # 2. Feed management
    capture_feed_screens

    # 3. Article interactions
    capture_article_screens

    # 4. Settings
    capture_settings_screens

    # 5. Admin screens
    capture_admin_screens(user)

    # 6. Special states
    capture_special_states
  end

  private

  def capture_dashboard_screens
    # Unread filter (default)
    visit dashboard_path
    wait_for_ui
    take_screenshot("01-dashboard-unread")
    analyze_screenshot("01-dashboard-unread", "Dashboard - Unread Filter")

    # Starred filter
    visit dashboard_path(filter: "starred")
    wait_for_ui
    take_screenshot("02-dashboard-starred")
    analyze_screenshot("02-dashboard-starred", "Dashboard - Starred Filter")

    # All articles
    visit dashboard_path(filter: "all")
    wait_for_ui
    take_screenshot("03-dashboard-all")
    analyze_screenshot("03-dashboard-all", "Dashboard - All Articles")

    # Article reading pane (select first article)
    visit dashboard_path(filter: "unread")
    first("[data-article-id]").click
    wait_for_ui
    take_screenshot("04-article-reading")
    analyze_screenshot("04-article-reading", "Article Reading Pane")
  end

  def capture_feed_screens
    visit feeds_path
    wait_for_ui
    take_screenshot("05-feeds-index")
    analyze_screenshot("05-feeds-index", "Feed Management Index")

    visit new_feed_path
    wait_for_ui
    take_screenshot("06-add-feed")
    analyze_screenshot("06-add-feed", "Add New Feed Form")
  end

  def capture_article_screens
    # Search
    visit search_path(q: "test")
    wait_for_ui
    take_screenshot("07-search-results")
    analyze_screenshot("07-search-results", "Search Results")
  end

  def capture_settings_screens
    visit settings_path
    wait_for_ui
    take_screenshot("08-settings")
    analyze_screenshot("08-settings", "User Settings")
  end

  def capture_admin_screens(user)
    user.update!(admin: true)

    visit admin_root_path
    wait_for_ui
    take_screenshot("09-admin-dashboard")
    analyze_screenshot("09-admin-dashboard", "Admin Dashboard")

    visit admin_users_path
    wait_for_ui
    take_screenshot("10-admin-users")
    analyze_screenshot("10-admin-users", "Admin Users List")

    visit admin_suggested_feeds_path
    wait_for_ui
    take_screenshot("11-admin-suggested-feeds")
    analyze_screenshot("11-admin-suggested-feeds", "Admin Suggested Feeds")

    visit admin_settings_path
    wait_for_ui
    take_screenshot("12-admin-settings")
    analyze_screenshot("12-admin-settings", "Admin Server Settings")
  end

  def capture_special_states
    # Onboarding (for new user)
    new_user = create_test_user(email: "newuser@example.com")
    login_as(new_user)
    visit dashboard_path
    wait_for_ui
    take_screenshot("13-onboarding")
    analyze_screenshot("13-onboarding", "Onboarding Modal")

    # Empty state (user with no feeds)
    empty_user = create_test_user(email: "empty@example.com")
    login_as(empty_user)
    visit dashboard_path
    wait_for_ui
    take_screenshot("14-empty-state")
    analyze_screenshot("14-empty-state", "Empty State (No Feeds)")

    # Flash messages
    login_as(create_test_user)
    visit dashboard_path
    page.execute_script("document.body.insertAdjacentHTML('beforeend', '<div class=\"fixed bottom-6 right-6 z-50\"><div class=\"px-4 py-3 rounded-md shadow-lg bg-green-100 border border-green-400 text-green-700\">Success message test</div></div>')")
    wait_for_ui
    take_screenshot("15-flash-success")
    analyze_screenshot("15-flash-success", "Flash Success Message")

    # Keyboard shortcuts
    visit dashboard_path
    page.execute_script("document.querySelector('[data-controller=\"keyboard\"]').dispatchEvent(new CustomEvent('show-help'))")
    wait_for_ui
    take_screenshot("16-keyboard-help")
    analyze_screenshot("16-keyboard-help", "Keyboard Shortcuts Help")
  end

  # ============================================================
  # HELPER METHODS
  # ============================================================

  def take_screenshot(name)
    # Light mode
    page.execute_script("document.documentElement.classList.remove('dark')")
    page.execute_script("localStorage.setItem('theme', 'light')")
    wait_for_ui
    screenshot_path = SCREENSHOT_DIR.join("#{name}-light.png")
    page.save_screenshot(screenshot_path)
    puts "📸 Captured: #{name}-light.png"

    # Dark mode
    page.execute_script("document.documentElement.classList.add('dark')")
    page.execute_script("localStorage.setItem('theme', 'dark')")
    wait_for_ui
    screenshot_path = SCREENSHOT_DIR.join("#{name}-dark.png")
    page.save_screenshot(screenshot_path)
    puts "📸 Captured: #{name}-dark.png"
  end

  def analyze_screenshot(filename, description)
    issues = []

    # Check for common CSS issues
    issues.concat(check_contrast_issues)
    issues.concat(check_focus_states)
    issues.concat(check_layout_issues)
    issues.concat(check_dark_mode_completeness)

    if issues.any?
      @detected_issues << {
        screenshot: filename,
        description: description,
        issues: issues
      }
    end
  end

  def check_contrast_issues
    issues = []

    # Check for yellow-500 on white (poor contrast)
    yellow_elements = page.all(".text-yellow-500, .text-yellow-400", visible: true)
    if yellow_elements.any?
      issues << "Poor contrast: Yellow text detected (may fail WCAG on light backgrounds)"
    end

    # Check for very light gray text
    light_gray = page.all(".text-gray-300, .text-gray-200", visible: true)
    if light_gray.any?
      issues << "Potential contrast issue: Very light gray text detected"
    end

    issues
  end

  def check_focus_states
    issues = []

    # Get all interactive elements
    interactive = page.all("button, a, input, select, textarea", visible: true)

    interactive.each do |element|
      # Check if element has focus styles defined
      has_focus_ring = element["class"].to_s.include?("focus:")
      has_focus_visible = element["class"].to_s.include?("focus-visible:")

      unless has_focus_ring || has_focus_visible
        issues << "Missing focus state on #{element.tag_name}#{element["class"].present? ? ".#{element["class"]}" : ""}"
      end
    end

    issues.uniq.first(5) # Limit to first 5 to avoid spam
  end

  def check_layout_issues
    issues = []

    # Check for horizontal overflow
    has_overflow = page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    if has_overflow
      issues << "Horizontal overflow detected (content wider than viewport)"
    end

    # Check for overlapping fixed elements
    fixed_elements = page.all("[style*='position: fixed'], .fixed", visible: true)
    if fixed_elements.count > 3
      issues << "Multiple fixed position elements may cause stacking issues"
    end

    issues
  end

  def check_dark_mode_completeness
    issues = []

    # Check for elements without dark: variants in dark mode
    in_dark_mode = page.evaluate_script("document.documentElement.classList.contains('dark')")

    if in_dark_mode
      # Check for hardcoded background colors
      bg_elements = page.all("[class*='bg-white'], [class*='bg-gray-50']", visible: true)
      bg_elements.each do |el|
        classes = el["class"].to_s
        unless classes.include?("dark:")
          issues << "Element may be missing dark mode: #{classes.split.first}"
        end
      end
    end

    issues.uniq.first(5)
  end

  def generate_report
    File.open(REPORT_FILE, "w") do |f|
      f.puts "# UI Audit Report\n\n"
      f.puts "Generated: #{Time.current}\n\n"
      f.puts "## Screenshots Captured\n\n"
      f.puts "All screenshots saved to: `#{SCREENSHOT_DIR}`\n\n"
      f.puts "Screenshots captured (light & dark mode):\n"

      Dir.glob(SCREENSHOT_DIR.join("*.png")).sort.each do |screenshot|
        f.puts "- #{File.basename(screenshot)}"
      end

      if @detected_issues.any?
        f.puts "\n## Detected Issues\n\n"

        @detected_issues.each do |issue_data|
          f.puts "### #{issue_data[:description]} (#{issue_data[:screenshot]})\n"
          issue_data[:issues].each do |issue|
            f.puts "- ⚠️ #{issue}"
          end
          f.puts "\n"
        end
      else
        f.puts "\n## No Major Issues Detected\n\n"
        f.puts "All screens passed automated checks. Manual review still recommended."
      end

      f.puts "\n## Recommendations\n\n"
      f.puts "1. Review all screenshots in `#{SCREENSHOT_DIR}`"
      f.puts "2. Check for visual consistency between light and dark modes"
      f.puts "3. Verify all interactive elements have visible focus states"
      f.puts "4. Ensure color contrast meets WCAG 2.1 AA standards"
      f.puts "5. Test keyboard navigation on all screens"
    end

    puts "\n📊 Report generated: #{REPORT_FILE}"
  end

  def create_test_user(email: "test@example.com")
    User.create!(
      email_address: email,
      password: "password123",
      password_confirmation: "password123",
      confirmed_at: Time.current
    )
  end

  def create_test_feed
    Feed.create!(
      title: "Test Feed",
      feed_url: "https://example.com/feed.xml",
      site_url: "https://example.com",
      last_fetched_at: Time.current
    )
  end

  def create_test_articles(feed)
    5.times do |i|
      feed.articles.create!(
        title: "Test Article #{i + 1}",
        content: "This is test content for article #{i + 1}. " * 20,
        url: "https://example.com/article#{i + 1}",
        guid: "test-article-#{i + 1}",
        published_at: i.hours.ago
      )
    end
  end

  def login_as(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password123"
    click_button "Sign in"
    wait_for_ui
  end

  def wait_for_ui
    sleep 0.5 # Allow for animations and Turbo frames
  end
end
