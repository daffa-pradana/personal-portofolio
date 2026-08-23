require "test_helper"

class KnowledgeRetrieverTest < ActiveSupport::TestCase
  setup { @retriever = KnowledgeRetriever.new }

  test "finds the entry whose title matches the question" do
    results = @retriever.retrieve("What is Daffa's tech stack?")

    assert_equal knowledge_entries(:stack), results.first
  end

  test "matches on content when the title does not mention the term" do
    results = @retriever.retrieve("Does he know Sidekiq?")

    assert_includes results, knowledge_entries(:stack)
  end

  test "matches on category" do
    results = @retriever.retrieve("Tell me about his experience")

    assert_equal knowledge_entries(:experience), results.first
  end

  # A title hit outranks a body hit, so the most on-topic entry leads the
  # context the model receives.
  test "ranks a title match above a content-only match" do
    results = @retriever.retrieve("kubernetes")

    assert_equal knowledge_entries(:unpositioned), results.first
  end

  # Grounding the model in everything beats grounding it in nothing.
  test "falls back to all entries when nothing matches" do
    results = @retriever.retrieve("xylophone quarterly synergy")

    assert_equal KnowledgeEntry.count, results.size
  end

  test "falls back to all entries when the question is only stop words" do
    results = @retriever.retrieve("what is the who and why")

    assert_equal KnowledgeEntry.count, results.size
  end

  test "falls back to all entries for a blank question" do
    assert_equal KnowledgeEntry.count, @retriever.retrieve("").size
    assert_equal KnowledgeEntry.count, @retriever.retrieve(nil).size
  end

  test "returns an empty list when there is no knowledge at all" do
    assert_empty KnowledgeRetriever.new(scope: KnowledgeEntry.none).retrieve("anything")
  end

  test "caps how many entries it returns" do
    results = @retriever.retrieve("daffa")

    assert_operator results.size, :<=, KnowledgeRetriever::MAX_ENTRIES
  end

  # "daffa" is a stop word precisely because it appears in nearly every
  # entry, so it carries no signal for ranking.
  test "ignores the subject's own name as a search term" do
    assert_equal KnowledgeEntry.count, @retriever.retrieve("daffa").size
  end

  test "ignores very short terms" do
    # "is" and "he" are too short to match anything on their own.
    assert_equal KnowledgeEntry.count, @retriever.retrieve("is he").size
  end

  test "is case insensitive" do
    assert_equal @retriever.retrieve("RAILS").first, @retriever.retrieve("rails").first
  end

  test "keeps a stable order for equally scored entries" do
    first_pass = @retriever.retrieve("daffa").map(&:id)
    second_pass = @retriever.retrieve("daffa").map(&:id)

    assert_equal first_pass, second_pass
  end
end
