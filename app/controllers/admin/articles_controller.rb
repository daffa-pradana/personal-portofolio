module Admin
  class ArticlesController < BaseController
    before_action :set_article, only: %i[ edit update destroy ]

    def index
      @articles = Article.with_attached_cover_image.order(position: :asc, created_at: :desc)
    end

    def new
      @article = Article.new
    end

    def create
      @article = Article.new(article_params)

      if @article.save
        redirect_to admin_articles_path, notice: "Article created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @article.update(article_params)
        redirect_to admin_articles_path, notice: "Article updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @article.destroy
      redirect_to admin_articles_path, notice: "Article deleted.", status: :see_other
    end

    private
      def set_article
        @article = Article.find_by!(slug: params[:slug])
      end

      # tags is a Postgres array column, but the form takes it as a single
      # comma-separated text field (see CLAUDE.md: "simple, functional UI").
      # params.expect treats it as a plain scalar; split it into an array
      # ourselves before it reaches the model.
      def article_params
        permitted = params.expect(
          article: [ :title, :subtitle, :slug, :article_type, :status, :tags,
                     :button_label, :button_url, :position, :cover_image, :body ]
        )
        permitted[:tags] = permitted[:tags].to_s.split(",").map(&:strip).reject(&:blank?) if permitted.key?(:tags)
        permitted
      end
  end
end
