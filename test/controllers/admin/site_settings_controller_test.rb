require "test_helper"

class Admin::SiteSettingsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as User.take }

  test "requires authentication" do
    sign_out

    get admin_site_settings_path

    assert_redirected_to new_session_path
  end

  test "index lists all settings" do
    get admin_site_settings_path

    assert_response :success
    assert_select "label", text: "cv_url"
    assert_select "label", text: "configured_example"
  end

  test "update changes a setting's value" do
    setting = site_settings(:cv_url)

    patch admin_site_setting_path(setting), params: { site_setting: { value: "https://example.com/cv.pdf" } }

    assert_redirected_to admin_site_settings_path
    assert_equal "https://example.com/cv.pdf", setting.reload.value
  end

  # No new/create/destroy routes — settings are a fixed, seeded registry.
  test "there is no route to create a setting" do
    assert_raises(NameError) { new_admin_site_setting_path }
  end
end
