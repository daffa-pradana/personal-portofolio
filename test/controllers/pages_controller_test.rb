require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  # ApplicationController adds `before_action :require_authentication` for the
  # admin CMS, which silently locks every controller that doesn't opt out. These
  # guard the public site against exactly that.
  test "landing page is reachable without signing in" do
    get root_path

    assert_response :success
  end

  # Proves the opt-out above is actually load-bearing: authentication really is
  # required by default, so if PagesController ever loses its
  # `allow_unauthenticated_access` the tests above start failing for real.
  test "a controller without the opt-out does require authentication" do
    delete session_path

    assert_redirected_to new_session_path
  end

  test "landing page shows published case studies" do
    get root_path

    assert_select "h3", text: articles(:jira_integration).title
    assert_select "h3", text: articles(:goal_custom_order).title
  end

  test "landing page hides drafts and blog posts from the projects section" do
    get root_path

    assert_select "h3", text: articles(:unpublished_case_study).title, count: 0
    assert_select "h3", text: articles(:published_blog_post).title, count: 0
  end

  test "landing page still renders for a signed-in admin" do
    sign_in_as User.take

    get root_path

    assert_response :success
  end

  test "hides the CV button when no cv_url is configured" do
    get root_path

    assert_select "a", text: "Download CV", count: 0
  end

  test "shows the CV button pointing at the configured cv_url" do
    SiteSetting[:cv_url] = "https://example.com/daffa-cv.pdf"

    get root_path

    assert_select "a[href=?]", "https://example.com/daffa-cv.pdf", text: "Download CV"
  end

  test "opens an externally hosted CV in a new tab rather than downloading it" do
    SiteSetting[:cv_url] = "https://example.com/daffa-cv.pdf"

    get root_path

    assert_select "a[href^='http'][target='_blank'][rel='noopener noreferrer']", text: "Download CV"
  end

  test "uses the download attribute for a same-origin CV path" do
    SiteSetting[:cv_url] = "/daffa-cv.pdf"

    get root_path

    assert_select "a[href=?][download]", "/daffa-cv.pdf", text: "Download CV"
  end
end
