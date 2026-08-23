require "test_helper"

class ArticlesHelperTest < ActionView::TestCase
  # The RAG case study's CTA is seeded as "#chat", and the same card renders on
  # /articles and /articles/:slug where no #chat section exists — so a bare
  # anchor href would be a dead link.
  test "resolves an in-page anchor against the landing page" do
    article = Article.new(button_url: "#chat")

    assert_equal root_path(anchor: "chat"), article_cta_url(article)
  end

  test "leaves an external url untouched" do
    article = Article.new(button_url: "https://happy5.co")

    assert_equal "https://happy5.co", article_cta_url(article)
  end

  test "external links open in a new tab" do
    article = Article.new(button_url: "https://happy5.co")

    assert_equal({ target: "_blank", rel: "noopener noreferrer" }, article_cta_link_options(article))
  end

  # Opening an anchor in a new tab would defeat the scroll entirely.
  test "anchor links stay in the current tab" do
    article = Article.new(button_url: "#chat")

    assert_empty article_cta_link_options(article)
  end
end
