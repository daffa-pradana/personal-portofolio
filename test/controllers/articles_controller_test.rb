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

  # Nothing else attaches a real cover_image and renders a page — without this,
  # a broken variant() call (wrong name, bad processing option) would only
  # surface in production, on the first real upload.
  test "show renders the :hero variant for an attached cover image" do
    article = articles(:jira_integration)
    article.cover_image.attach(io: file_fixture("cover_image.png").open, filename: "cover.png", content_type: "image/png")

    get article_path(article)

    assert_response :success
    assert_select "img[src*='cover.png']"
  end

  test "index renders the :thumb variant for an attached cover image" do
    article = articles(:jira_integration)
    article.cover_image.attach(io: file_fixture("cover_image.png").open, filename: "cover.png", content_type: "image/png")

    get articles_path

    assert_response :success
    assert_select "img[src*='cover.png']"
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

  # An anchor CTA (the RAG case study ships "#chat") has to point back at the
  # landing page: there is no #chat section on an article page, so a bare
  # "#chat" href would be a dead link.
  test "show points an anchor CTA back at the landing page" do
    article = articles(:jira_integration)
    article.update!(button_label: "Try Here!", button_url: "#chat")

    get article_path(article)

    assert_select "a[href=?]", "/#chat", text: "Try Here!"
  end

  test "index points an anchor CTA back at the landing page" do
    articles(:jira_integration).update!(button_label: "Try Here!", button_url: "#chat")

    get articles_path

    assert_select "turbo-frame#articles a[href=?]", "/#chat", text: "Try Here!"
  end
end
