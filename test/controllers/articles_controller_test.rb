require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  test "index is reachable without signing in" do
    get articles_path

    assert_response :success
  end

  test "index lists published articles of both types" do
    get articles_path

    assert_select "h3", text: articles(:jira_integration).title
    assert_select "h3", text: articles(:published_blog_post).title
  end

  test "index hides drafts" do
    get articles_path

    assert_select "h3", text: articles(:unpublished_case_study).title, count: 0
  end

  test "index filters to blog posts only" do
    get articles_path, params: { kind: "blog" }

    assert_select "h3", text: articles(:published_blog_post).title
    assert_select "h3", text: articles(:jira_integration).title, count: 0
  end

  test "index filters to case studies only" do
    get articles_path, params: { kind: "case_study" }

    assert_select "h3", text: articles(:jira_integration).title
    assert_select "h3", text: articles(:published_blog_post).title, count: 0
  end

  test "index ignores an unrecognized kind and falls back to all" do
    get articles_path, params: { kind: "nonsense" }

    assert_select "h3", text: articles(:jira_integration).title
    assert_select "h3", text: articles(:published_blog_post).title
  end

  test "index wraps the tabs and grid in a single turbo frame" do
    get articles_path

    assert_select "turbo-frame#articles"
  end

  # Regression test: a card's link lives inside turbo_frame_tag "articles"
  # on this page. Without data-turbo-frame="_top", Turbo scopes the click to
  # that frame, fetches the show page looking for a matching #articles frame
  # in it (there isn't one), and renders "Content missing" instead of
  # navigating — without even updating the URL, since frame navigations
  # don't touch browser history.
  test "a card's link breaks out of the surrounding turbo frame" do
    get articles_path

    assert_select "turbo-frame#articles a[href=?][data-turbo-frame=?]",
      article_path(articles(:jira_integration)), "_top"
  end

  test "show renders a published article" do
    get article_path(articles(:jira_integration))

    assert_response :success
    assert_select "h1", text: articles(:jira_integration).title
  end

  test "show 404s for a draft" do
    get article_path(articles(:unpublished_case_study))

    assert_response :not_found
  end

  test "show 404s for an unknown slug" do
    get "/articles/does-not-exist"

    assert_response :not_found
  end

  test "show renders the case study CTA button when present" do
    get article_path(articles(:jira_integration))

    assert_select "a[href=?]", articles(:jira_integration).button_url, text: articles(:jira_integration).button_label
  end
end
