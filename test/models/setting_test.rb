require "test_helper"

class SettingTest < ActiveSupport::TestCase
  # Validation tests
  test "valid setting" do
    setting = Setting.new(key: "test_key", value: "test_value")
    assert setting.valid?
  end

  test "requires key" do
    setting = Setting.new(value: "test_value")
    assert_not setting.valid?
    assert_includes setting.errors[:key], "can't be blank"
  end

  test "requires unique key" do
    Setting.create!(key: "unique_key", value: "value1")
    duplicate = Setting.new(key: "unique_key", value: "value2")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "allows nil value" do
    setting = Setting.new(key: "test_key", value: nil)
    assert setting.valid?
  end

  test "allows empty value" do
    setting = Setting.new(key: "test_key", value: "")
    assert setting.valid?
  end

  # Class method: get
  test "get returns value for existing key" do
    setting = settings(:test_setting_one)
    assert_equal "test_value_one", Setting.get("test_key_one")
  end

  test "get returns nil for non-existent key" do
    assert_nil Setting.get("non_existent_key")
  end

  test "get returns default value for non-existent key" do
    assert_equal "default_value", Setting.get("non_existent_key", "default_value")
  end

  test "get returns actual value over default when key exists" do
    setting = settings(:test_setting_one)
    assert_equal "test_value_one", Setting.get("test_key_one", "default_value")
  end

  test "get handles nil default" do
    assert_nil Setting.get("non_existent_key", nil)
  end

  # Class method: set
  test "set creates new setting when key doesn't exist" do
    assert_difference "Setting.count", 1 do
      Setting.set("new_key", "new_value")
    end

    assert_equal "new_value", Setting.get("new_key")
  end

  test "set updates existing setting when key exists" do
    setting = settings(:test_setting_one)
    original_value = setting.value

    assert_no_difference "Setting.count" do
      Setting.set("test_key_one", "updated_value")
    end

    assert_equal "updated_value", Setting.get("test_key_one")
    assert_not_equal original_value, Setting.get("test_key_one")
  end

  test "set returns the value" do
    result = Setting.set("test_key", "test_value")
    assert_equal "test_value", result
  end

  test "set converts value to string" do
    Setting.set("integer_key", 123)
    assert_equal "123", Setting.get("integer_key")

    Setting.set("boolean_key", true)
    assert_equal "true", Setting.get("boolean_key")

    Setting.set("boolean_key_false", false)
    assert_equal "false", Setting.get("boolean_key_false")
  end

  test "set handles nil value" do
    Setting.set("nil_key", nil)
    assert_equal "", Setting.get("nil_key")
  end

  # Class method: require_admin_confirmation?
  test "require_admin_confirmation? returns true when set to true" do
    Setting.set("require_admin_confirmation", "true")
    assert Setting.require_admin_confirmation?
  end

  test "require_admin_confirmation? returns false when set to false" do
    Setting.set("require_admin_confirmation", "false")
    assert_not Setting.require_admin_confirmation?
  end

  test "require_admin_confirmation? returns false by default" do
    Setting.destroy_all
    assert_not Setting.require_admin_confirmation?
  end

  test "require_admin_confirmation? is case sensitive" do
    Setting.set("require_admin_confirmation", "True")
    assert_not Setting.require_admin_confirmation?

    Setting.set("require_admin_confirmation", "TRUE")
    assert_not Setting.require_admin_confirmation?
  end

  # Class method: require_admin_confirmation= (setter)
  test "require_admin_confirmation= sets value to true" do
    Setting.require_admin_confirmation = true
    assert_equal "true", Setting.get("require_admin_confirmation")
    assert Setting.require_admin_confirmation?
  end

  test "require_admin_confirmation= sets value to false" do
    Setting.require_admin_confirmation = false
    assert_equal "false", Setting.get("require_admin_confirmation")
    assert_not Setting.require_admin_confirmation?
  end

  test "require_admin_confirmation= accepts string true" do
    Setting.require_admin_confirmation = "true"
    assert_equal "true", Setting.get("require_admin_confirmation")
    assert Setting.require_admin_confirmation?
  end

  test "require_admin_confirmation= accepts string false" do
    Setting.require_admin_confirmation = "false"
    assert_equal "false", Setting.get("require_admin_confirmation")
    assert_not Setting.require_admin_confirmation?
  end

  # Class method: require_admin_confirmation (alias)
  test "require_admin_confirmation aliases require_admin_confirmation?" do
    Setting.set("require_admin_confirmation", "true")
    assert Setting.require_admin_confirmation
    assert_equal Setting.require_admin_confirmation?, Setting.require_admin_confirmation
  end

  # Edge cases
  test "handles very long key" do
    long_key = "k" * 1000
    setting = Setting.new(key: long_key, value: "value")
    # Should save or fail based on database constraints
    assert setting.save || !setting.valid?
  end

  test "handles very long value" do
    long_value = "v" * 10000
    setting = Setting.new(key: "long_value_key", value: long_value)
    assert setting.valid?
  end

  test "handles special characters in key" do
    setting = Setting.new(key: "special!@#$%^&*()", value: "value")
    assert setting.valid?
  end

  test "handles special characters in value" do
    setting = Setting.new(key: "key", value: "special!@#$%^&*()")
    assert setting.valid?
  end

  test "get and set work together" do
    Setting.set("toggle", "on")
    assert_equal "on", Setting.get("toggle")

    Setting.set("toggle", "off")
    assert_equal "off", Setting.get("toggle")
  end

  test "multiple settings can coexist" do
    Setting.set("key1", "value1")
    Setting.set("key2", "value2")
    Setting.set("key3", "value3")

    assert_equal "value1", Setting.get("key1")
    assert_equal "value2", Setting.get("key2")
    assert_equal "value3", Setting.get("key3")
  end

  # Fixture tests
  test "fixtures are valid" do
    setting = settings(:test_setting_one)
    assert setting.valid?
    assert_equal "test_key_one", setting.key
    assert_equal "test_value_one", setting.value
  end

  test "can update fixture setting" do
    setting = settings(:test_setting_one)
    setting.value = "new_value"
    assert setting.save
    assert_equal "new_value", setting.reload.value
  end
end
