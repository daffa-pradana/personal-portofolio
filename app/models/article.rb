class Article < ApplicationRecord
  enum :article_type, { blog: 0, case_study: 1 }
  enum :status, { draft: 0, published: 1 }

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug
  before_save :stamp_published_at

  def to_param
    slug
  end

  private
    def generate_slug
      return if slug.present? || title.blank?

      base = title.parameterize.presence || "article"
      candidate = base
      counter = 2

      while Article.where.not(id: id).exists?(slug: candidate)
        candidate = "#{base}-#{counter}"
        counter += 1
      end

      self.slug = candidate
    end

    def stamp_published_at
      self.published_at ||= Time.current if published?
    end
end
