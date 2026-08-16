class Article < ApplicationRecord
  # Average adult reading speed, per the CLAUDE.md spec for the "N min read"
  # label on article pages.
  WORDS_PER_MINUTE = 200

  has_rich_text :body
  has_one_attached :cover_image

  enum :article_type, { blog: 0, case_study: 1 }
  enum :status, { draft: 0, published: 1 }

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug
  before_save :stamp_published_at
  before_save :calculate_reading_time

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

    # Stored rather than computed on read so the articles index can show it
    # without loading every body. Recalculated on every save, since that is the
    # only moment the body can have changed.
    def calculate_reading_time
      word_count = body.to_plain_text.split.size

      self.reading_time = word_count.zero? ? nil : (word_count / WORDS_PER_MINUTE.to_f).ceil
    end
end
