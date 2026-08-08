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

  test "calculates reading time from body word count" do
    article = Article.create!(title: "Four Hundred Words", body: "<p>#{words(400)}</p>")

    assert_equal 2, article.reading_time
  end

  test "rounds a partial reading minute up" do
    article = Article.create!(title: "Barely Anything", body: "<p>#{words(10)}</p>")

    assert_equal 1, article.reading_time
  end

  test "ignores markup when counting words" do
    plain = Article.create!(title: "Plain", body: "<p>#{words(200)}</p>")
    marked_up = Article.create!(title: "Marked Up", body: "<h2>#{words(200)}</h2>")

    assert_equal plain.reading_time, marked_up.reading_time
  end

  test "leaves reading time nil when there is no body" do
    article = Article.create!(title: "Nothing Written Yet")

    assert_nil article.reading_time
  end

  test "recalculates reading time when the body changes" do
    article = Article.create!(title: "Growing Post", body: "<p>#{words(100)}</p>")
    assert_equal 1, article.reading_time

    article.update!(body: "<p>#{words(1000)}</p>")

    assert_equal 5, article.reading_time
  end

  test "clears reading time when the body is emptied" do
    article = Article.create!(title: "Emptied Post", body: "<p>#{words(400)}</p>")
    assert_equal 2, article.reading_time

    article.update!(body: "")

    assert_nil article.reading_time
  end

  test "accepts a cover image attachment" do
    article = articles(:jira_integration)

    article.cover_image.attach(
      io: file_fixture("cover_image.png").open,
      filename: "cover_image.png",
      content_type: "image/png"
    )

    assert article.reload.cover_image.attached?
    assert_equal "image/png", article.cover_image.content_type
  end

  test "has no cover image by default" do
    assert_not articles(:goal_custom_order).cover_image.attached?
  end

  private
    def words(count)
      Array.new(count) { "word" }.join(" ")
    end
end
