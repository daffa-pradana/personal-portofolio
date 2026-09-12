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

  test "returns an empty list when there is no knowledge at all" do
    assert_empty KnowledgeRetriever.new(scope: KnowledgeEntry.none).retrieve("anything")
  end

  # An unmatched question has no relevance signal to sort by, so the order it
  # returns should be the curated one (within the cap).
  test "preserves the curated order when nothing matches" do
    results = @retriever.retrieve("xylophone quarterly synergy")

    assert_equal KnowledgeEntry.ordered.first(KnowledgeRetriever::CAP).map(&:id), results.map(&:id)
  end

  # "daffa" is a stop word precisely because it appears in nearly every
  # entry, so it carries no signal for ranking.
  test "ignores the subject's own name as a search term" do
    assert_equal KnowledgeEntry.ordered.first(KnowledgeRetriever::CAP).map(&:id),
      @retriever.retrieve("daffa").map(&:id)
  end

  test "ignores very short terms" do
    # "is" and "he" are too short to match anything on their own.
    assert_equal KnowledgeEntry.ordered.first(KnowledgeRetriever::CAP).map(&:id),
      @retriever.retrieve("is he").map(&:id)
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

  # --- the cap + floor design (deferred fix from PROGRESS.md) --------------
  #
  # Fixtures alone (4 entries) never exceed CAP (6), so these build a larger
  # scope to actually exercise truncation.

  test "caps results even when nothing scores and many entries exist" do
    entries = 10.times.map { |i| KnowledgeEntry.create!(category: "misc", title: "Filler #{i}", content: "Nothing relevant.", position: 100 + i) }
    retriever = KnowledgeRetriever.new(scope: KnowledgeEntry.where(id: entries))

    assert_equal KnowledgeRetriever::CAP, retriever.retrieve("xylophone quarterly synergy").size
  end

  test "always includes the contact entry even when it doesn't rank in the top scores" do
    contact = KnowledgeEntry.create!(category: "contact", title: "Reach out", content: "Email Daffa.", position: 999)
    skills = 10.times.map { |i| KnowledgeEntry.create!(category: "skills", title: "Ruby skill #{i}", content: "Ruby on Rails expertise.", position: i) }
    retriever = KnowledgeRetriever.new(scope: KnowledgeEntry.where(id: [ contact, *skills ]))

    # Every "Ruby skill" entry outscores "Reach out" for this question, so
    # without the floor, "Reach out" would fall outside the top CAP.
    results = retriever.retrieve("Tell me about Ruby skills")

    assert_includes results, contact
    assert_equal KnowledgeRetriever::CAP, results.size
  end

  test "does not duplicate the contact entry when it already ranks in the top scores" do
    results = @retriever.retrieve("how can I contact him")

    assert_equal 1, results.count { |entry| entry == knowledge_entries(:contact) }
  end

  test "is a no-op when there is no contact-category entry at all" do
    retriever = KnowledgeRetriever.new(scope: KnowledgeEntry.where.not(category: "contact"))

    results = retriever.retrieve("anything")

    assert_not_includes results.map(&:category), "contact"
  end
end
