module Admin
  class DashboardController < BaseController
    def index
      @article_count = Article.count
      @published_count = Article.published.count
      @draft_count = Article.draft.count
      @knowledge_entry_count = KnowledgeEntry.count
    end
  end
end
