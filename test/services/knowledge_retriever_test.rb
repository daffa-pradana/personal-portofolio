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

  # Scoring orders, it never filters — so every entry is always sent while the
  # base fits under the cap. This is the core guarantee of the design: an
  # imperfectly-worded question must not starve the model of context.
  test "returns every entry regardless of how well the question matches" do
    [
      "What is Daffa's tech stack?",   # strong match
      "why should I hire him",          # weak match
      "is he any good?",               # barely matches anything
      "xylophone quarterly synergy",   # matches nothing
      "what is the who and why",       # only stop words
      "",
      nil
    ].each do |question|
      assert_equal KnowledgeEntry.count, @retriever.retrieve(question).size,
        "expected the full knowledge base for #{question.inspect}"
    end
  end

  # Regression: contact details were being dropped from nearly every prompt
  # while the system prompt was telling the model to point visitors there.
  test "always includes the contact entry" do
    [ "What is Daffa's tech stack?", "why should I hire him", "is he any good?" ].each do |question|
      categories = @retriever.retrieve(question).map(&:category)

      assert_includes categories, "personal",
        "contact context missing for #{question.inspect}"
    end
  end

  test "returns an empty list when there is no knowledge at all" do
    assert_empty KnowledgeRetriever.new(scope: KnowledgeEntry.none).retrieve("anything")
  end

  test "caps how many entries it returns" do
    results = @retriever.retrieve("daffa")

    assert_operator results.size, :<=, KnowledgeRetriever::MAX_ENTRIES
  end

  # Guards the drift that actually happened: MAX_ENTRIES was 8 while the seed
  # file grew to 13, so the tail was quietly dropped — including the contact
  # details the system prompt tells the model to promote. Reading the real seed
  # file (not fixtures) is the point: this fails when the shipped knowledge
  # base outgrows the cap, rather than degrading in silence.
  test "the cap is large enough for the entire shipped knowledge base" do
    seeded = YAML.load_file(Rails.root.join("db/seeds/knowledge_entries.yml")).size

    assert_operator KnowledgeRetriever::MAX_ENTRIES, :>=, seeded,
      "MAX_ENTRIES (#{KnowledgeRetriever::MAX_ENTRIES}) is below the #{seeded} seeded " \
      "entries, so retrieval will silently truncate the knowledge base"
  end

  # An unmatched question has no relevance signal to sort by, so the order it
  # returns should be the curated one.
  test "preserves the curated order when nothing matches" do
    results = @retriever.retrieve("xylophone quarterly synergy")

    assert_equal KnowledgeEntry.ordered.map(&:id), results.map(&:id)
  end

  # "daffa" is a stop word precisely because it appears in nearly every
  # entry, so it carries no signal for ranking.
  test "ignores the subject's own name as a search term" do
    assert_equal KnowledgeEntry.ordered.map(&:id), @retriever.retrieve("daffa").map(&:id)
  end

  test "ignores very short terms" do
    # "is" and "he" are too short to match anything on their own.
    assert_equal KnowledgeEntry.ordered.map(&:id), @retriever.retrieve("is he").map(&:id)
  end

  test "is case insensitive" do
    assert_equal @retriever.retrieve("RAILS").map(&:id), @retriever.retrieve("rails").map(&:id)
  end

  # Ruby does not guarantee sort_by is stable, so the retriever tiebreaks on
  # position explicitly. Without that, equal scores could reorder between
  # identical requests and the same question would drift.
  test "returns a deterministic order for repeated identical questions" do
    first_pass = @retriever.retrieve("Sidekiq and Kubernetes").map(&:id)
    second_pass = @retriever.retrieve("Sidekiq and Kubernetes").map(&:id)

    assert_equal first_pass, second_pass
  end
end
