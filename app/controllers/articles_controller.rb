class ArticlesController < ApplicationController
  # Visitor-facing, same as PagesController — see its comment for why every
  # such controller needs this opt-out.
  allow_unauthenticated_access

  KINDS = %w[ all blog case_study ].freeze

  def index
    @kind = KINDS.include?(params[:kind]) ? params[:kind] : "all"

    @articles = Article.published.with_attached_cover_image.order(published_at: :desc)
    @articles = @articles.where(article_type: @kind) unless @kind == "all"
  end

  def show
    @article = Article.published.find_by!(slug: params[:slug])
  end
end
