class Article < ApplicationRecord
  # Average adult reading speed, per the CLAUDE.md spec for the "N min read"
  # label on article pages.
  WORDS_PER_MINUTE = 200

  has_rich_text :body

  # Named variants so cards/show pages stop serving full-resolution uploads.
  # :thumb matches the card's own aspect-[16/10] crop; :hero matches the show
  # page's aspect-video. Both lazy — Rails only resizes on first request for
  # that derivative (needs libvips; already in the Dockerfile, not required
  # for tests or dev unless you're actually viewing an uploaded image).
  has_one_attached :cover_image do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 800, 500 ], saver: { quality: 80 }
    attachable.variant :hero, resize_to_limit: [ 1200, 675 ], saver: { quality: 85 }
  end

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
