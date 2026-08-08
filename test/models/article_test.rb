require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "requires a title" do
    article = Article.new(title: nil)

    assert_not article.valid?
    assert_includes article.errors[:title], "can't be blank"
  end

  test "generates a slug from the title" do
    article = Article.create!(title: "H5 – Some New Case Study")

    assert_equal "h5-some-new-case-study", article.slug
  end

  test "keeps an explicitly provided slug" do
    article = Article.create!(title: "Anything", slug: "custom-slug")

    assert_equal "custom-slug", article.slug
  end

  test "suffixes a generated slug that collides with an existing one" do
    article = Article.create!(title: "H5 – Goal Custom Order")

    assert_equal "h5-goal-custom-order-2", article.slug
  end

  test "does not change the slug of an existing record on update" do
    article = articles(:jira_integration)

    article.update!(title: "A Completely Different Title")

    assert_equal "h5-jira-project-integration", article.slug
  end

  test "to_param returns the slug" do
    assert_equal "h5-jira-project-integration", articles(:jira_integration).to_param
  end

  test "stamps published_at when an article is first published" do
    article = Article.create!(title: "Freshly Published", status: :published)

    assert_not_nil article.published_at
  end

  test "does not restamp published_at on later saves" do
    article = articles(:jira_integration)
    original = article.published_at

    article.update!(subtitle: "Edited subtitle")

    assert_equal original, article.reload.published_at
  end

  test "leaves published_at nil for drafts" do
    article = Article.create!(title: "Still Cooking", status: :draft)

    assert_nil article.published_at
  end

  test "case_study scope excludes blog posts" do
    assert_includes Article.case_study, articles(:jira_integration)
    assert_not_includes Article.case_study, articles(:published_blog_post)
  end

  test "published scope excludes drafts" do
    assert_includes Article.published, articles(:jira_integration)
    assert_not_includes Article.published, articles(:unpublished_case_study)
  end

  test "landing page query returns published case studies in position order" do
    results = Article.case_study.published.order(:position).limit(3)

    assert_equal [ articles(:jira_integration), articles(:goal_custom_order) ], results.to_a
  end
end
