require "test_helper"

class KnowledgeEntryTest < ActiveSupport::TestCase
  test "requires a category, title and content" do
    entry = KnowledgeEntry.new

    assert_not entry.valid?
    assert_includes entry.errors[:category], "can't be blank"
    assert_includes entry.errors[:title], "can't be blank"
    assert_includes entry.errors[:content], "can't be blank"
  end

  test "position is optional" do
    entry = KnowledgeEntry.new(category: "skills", title: "T", content: "C")

    assert entry.valid?
  end

  test "ordered sorts by position ascending" do
    positions = KnowledgeEntry.ordered.map(&:position).compact

    assert_equal positions.sort, positions
  end

  # Postgres sorts NULLs highest on ASC by default, which would put
  # uncurated entries ahead of curated ones. The scope overrides that.
  test "ordered puts entries without a position last" do
    ordered = KnowledgeEntry.ordered.to_a

    assert_equal knowledge_entries(:unpositioned), ordered.last
  end

  test "to_context_line labels the content with its category and title" do
    assert_equal "[skills] Tech stack: Daffa works mainly in Ruby on Rails with PostgreSQL and Sidekiq.",
      knowledge_entries(:stack).to_context_line
  end
end
