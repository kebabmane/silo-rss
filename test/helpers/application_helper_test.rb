require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "format_user_time with short date" do
    Time.use_zone("America/New_York") do
      time = Time.utc(2025, 10, 7, 12, 0, 0)
      assert_equal "Oct 07, 2025", format_user_time(time, style: :short_date)
    end
  end

  test "format_user_time with long" do
    Time.use_zone("Europe/London") do
      time = Time.utc(2025, 10, 7, 12, 0, 0)
      assert_equal "October 07, 2025 at 01:00 PM", format_user_time(time, style: :long)
    end
  end
end
