require "test_helper"

class LitellmSettingTest < ActiveSupport::TestCase
  test "singleton instance returns same record" do
    setting1 = LitellmSetting.instance
    setting2 = LitellmSetting.instance

    assert_equal setting1.id, setting2.id
  end

  test "only one record should exist" do
    LitellmSetting.instance
    assert_equal 1, LitellmSetting.count
  end

  test "instance creates default values on first call" do
    LitellmSetting.delete_all
    setting = LitellmSetting.instance

    assert_not_nil setting.server_url
    assert_not_nil setting.default_model
    assert_equal false, setting.enabled
  end

  test "validates server_url presence when enabled" do
    setting = LitellmSetting.instance
    setting.enabled = true
    setting.server_url = nil

    assert_not setting.valid?
    assert_includes setting.errors[:server_url], "can't be blank"
  end

  test "validates default_model presence when enabled" do
    setting = LitellmSetting.instance
    setting.enabled = true
    setting.default_model = nil

    assert_not setting.valid?
    assert_includes setting.errors[:default_model], "can't be blank"
  end

  test "validates max_tokens is positive" do
    setting = LitellmSetting.instance
    setting.max_tokens = -100

    assert_not setting.valid?
    assert_includes setting.errors[:max_tokens], "must be greater than 0"
  end

  test "validates temperature range" do
    setting = LitellmSetting.instance

    setting.temperature = -1
    assert_not setting.valid?

    setting.temperature = 3
    assert_not setting.valid?

    setting.temperature = 1.0
    assert setting.valid?
  end

  test "configured? returns true when enabled with required fields" do
    setting = LitellmSetting.instance
    setting.update(enabled: true, server_url: "http://test:4000", default_model: "gpt-4")

    assert setting.configured?
  end

  test "configured? returns false when disabled" do
    setting = LitellmSetting.instance
    setting.update(enabled: false, server_url: "http://test:4000", default_model: "gpt-4")

    assert_not setting.configured?
  end
end
