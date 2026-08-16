require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get admin_root_path

    assert_redirected_to new_session_path
  end

  test "shows article counts" do
    sign_in_as User.take

    get admin_root_path

    assert_response :success
    assert_select "p", text: Article.count.to_s
    assert_select "p", text: Article.published.count.to_s
    assert_select "p", text: Article.draft.count.to_s
  end
end
