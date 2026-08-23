class KnowledgeEntry < ApplicationRecord
  validates :category, presence: true
  validates :title, presence: true
  validates :content, presence: true

  # NULLS LAST so entries without an explicit position sort after curated
  # ones rather than ahead of them (Postgres sorts NULL highest by default
  # on ASC). Retrieval order matters: KnowledgeRetriever truncates the
  # context it sends to the LLM, so position is a priority signal.
  scope :ordered, -> { order(Arel.sql("position ASC NULLS LAST, id ASC")) }

  def to_context_line
    "[#{category}] #{title}: #{content}"
  end
end
