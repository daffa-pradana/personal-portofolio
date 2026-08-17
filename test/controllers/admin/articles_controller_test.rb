require "test_helper"

class Admin::ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as User.take }

  test "requires authentication" do
    sign_out

    get admin_articles_path

    assert_redirected_to new_session_path
  end

  test "index lists all articles regardless of status or type" do
    get admin_articles_path

    assert_response :success
    assert_select "td", text: articles(:jira_integration).title
    assert_select "td", text: articles(:unpublished_case_study).title
    assert_select "td", text: articles(:published_blog_post).title
  end

  test "new renders the form" do
    get new_admin_article_path

    assert_response :success
  end

  test "create with valid params" do
    assert_difference("Article.count", 1) do
      post admin_articles_path, params: {
        article: {
          title: "A Brand New Article",
          article_type: "blog",
          status: "draft",
          tags: "Ruby, Rails"
        }
      }
    end

    article = Article.order(:created_at).last
    assert_redirected_to admin_articles_path
    assert_equal [ "Ruby", "Rails" ], article.tags
  end

  test "create with invalid params re-renders the form" do
    assert_no_difference("Article.count") do
      post admin_articles_path, params: { article: { title: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "edit renders the form for an existing article, looked up by slug" do
    get edit_admin_article_path(articles(:jira_integration))

    assert_response :success
  end

  test "update changes the article's attributes" do
    article = articles(:jira_integration)

    patch admin_article_path(article), params: { article: { subtitle: "Updated subtitle" } }

    assert_redirected_to admin_articles_path
    assert_equal "Updated subtitle", article.reload.subtitle
  end

  test "update with blank title re-renders the form" do
    article = articles(:jira_integration)

    patch admin_article_path(article), params: { article: { title: "" } }

    assert_response :unprocessable_entity
    assert_equal "H5 – Jira Project Integration", article.reload.title
  end

  test "destroy removes the article" do
    article = articles(:unpublished_case_study)

    assert_difference("Article.count", -1) do
      delete admin_article_path(article)
    end

    assert_redirected_to admin_articles_path
  end
end
