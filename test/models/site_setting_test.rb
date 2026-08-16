require "test_helper"

class SiteSettingTest < ActiveSupport::TestCase
  test "requires a key" do
    setting = SiteSetting.new(key: nil, value: "x")

    assert_not setting.valid?
  end

  test "requires the key to be unique" do
    duplicate = SiteSetting.new(key: "configured_example", value: "another")

    assert_not duplicate.valid?
  end

  test "normalizes keys to lowercase without surrounding whitespace" do
    setting = SiteSetting.create!(key: "  Contact_Email  ", value: "x")

    assert_equal "contact_email", setting.key
  end

  test "reads a configured value by key" do
    assert_equal "a value", SiteSetting[:configured_example]
  end

  test "accepts a string key as well as a symbol" do
    assert_equal "a value", SiteSetting["configured_example"]
  end

  test "returns nil for a key that does not exist" do
    assert_nil SiteSetting[:no_such_key]
  end

  test "treats a blank value as unset" do
    assert_nil SiteSetting[:blank_example]
  end

  test "treats a nil value as unset" do
    assert_nil SiteSetting[:cv_url]
  end

  test "writing creates a missing setting" do
    SiteSetting[:brand_new] = "hello"

    assert_equal "hello", SiteSetting[:brand_new]
  end

  test "writing updates an existing setting without duplicating the key" do
    SiteSetting[:configured_example] = "replaced"

    assert_equal "replaced", SiteSetting[:configured_example]
    assert_equal 1, SiteSetting.where(key: "configured_example").count
  end
end
