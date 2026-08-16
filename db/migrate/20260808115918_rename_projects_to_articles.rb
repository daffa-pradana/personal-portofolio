class RenameProjectsToArticles < ActiveRecord::Migration[8.0]
  # Throwaway model for the backfill. app/models/article.rb has validations,
  # enums and callbacks that will keep evolving after this migration ships —
  # this migration must keep running against the schema as it exists here.
  class Article < ActiveRecord::Base
    self.table_name = "articles"
  end

  # Every pre-existing row is a project that was live on the landing page.
  CASE_STUDY = 1
  PUBLISHED = 1

  def up
    rename_table :projects, :articles

    add_column :articles, :subtitle, :string
    add_column :articles, :slug, :string
    add_column :articles, :article_type, :integer, default: 0, null: false
    add_column :articles, :status, :integer, default: 0, null: false
    add_column :articles, :published_at, :datetime
    add_column :articles, :reading_time, :integer
    add_column :articles, :button_label, :string
    add_column :articles, :button_url, :string

    backfill_articles

    change_column_null :articles, :slug, false
    add_index :articles, :slug, unique: true
    add_index :articles, :article_type
    add_index :articles, :status
    add_index :articles, :published_at

    # description/live_url survive as subtitle/button_url above.
    # source_code_url has no equivalent in the Article schema and is nil on
    # every existing row, so it is dropped rather than carried forward.
    remove_column :articles, :description
    remove_column :articles, :live_url
    remove_column :articles, :source_code_url
  end

  def down
    add_column :articles, :description, :text
    add_column :articles, :live_url, :string
    add_column :articles, :source_code_url, :string

    Article.reset_column_information
    Article.find_each do |article|
      article.update_columns(description: article.subtitle, live_url: article.button_url)
    end

    # Indexes are dropped along with their columns.
    remove_column :articles, :subtitle
    remove_column :articles, :slug
    remove_column :articles, :article_type
    remove_column :articles, :status
    remove_column :articles, :published_at
    remove_column :articles, :reading_time
    remove_column :articles, :button_label
    remove_column :articles, :button_url

    rename_table :articles, :projects
  end

  private
    def backfill_articles
      Article.reset_column_information

      used_slugs = []
      Article.order(:id).each do |article|
        article.update_columns(
          subtitle: article.description,
          slug: unique_slug(article.title, used_slugs),
          article_type: CASE_STUDY,
          status: PUBLISHED,
          published_at: article.created_at,
          button_url: article.live_url,
          button_label: button_label_for(article.live_url)
        )
      end
    end

    def unique_slug(title, used_slugs)
      base = title.to_s.parameterize.presence || "article"
      candidate = base
      counter = 2

      while used_slugs.include?(candidate)
        candidate = "#{base}-#{counter}"
        counter += 1
      end

      used_slugs << candidate
      candidate
    end

    # Mirrors the label the projects partial used to hardcode, so cards render
    # identically once the label comes from the database instead of the view.
    def button_label_for(live_url)
      return nil if live_url.blank?

      live_url.start_with?("#") ? "Try Here!" : "Product Page"
    end
end
