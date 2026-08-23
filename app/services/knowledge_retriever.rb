# The "R" in RAG, kept deliberately simple: CLAUDE.md specifies
# "simple keyword-based retrieval", not embeddings. The knowledge base is a
# few dozen short entries about one person, so scoring beats similarity
# search here — and it needs no extra service, gem, or vector column.
#
# Scoring ORDERS the entries; it does not filter them. That distinction is the
# whole design. Filtering out zero-scoring entries seems obviously right and is
# actively harmful at this scale: keyword overlap between a short question and
# a short entry is sparse, so "What projects has Daffa worked on?" scored only
# 2 of 13 entries and "is he any good?" scored 1 — starving the model of
# context while a nonsense question, which matched nothing and hit the
# everything-fallback, got all 13. The contact details were absent from almost
# every prompt, even though the system prompt is told to point visitors there.
#
# Since the entire base is ~1,300 tokens (see MAX_ENTRIES), the cheap and
# better answer is to send all of it, best-ranked first, and let the model pick.
class KnowledgeRetriever
  # Words that would match nearly every entry and so carry no signal.
  STOP_WORDS = %w[
    a an and are as at be but by for from has have how i in is it its of on or
    that the this to was what when where which who why with you your daffa
  ].to_set.freeze

  # Anything shorter is noise ("is", "do") once stop words are removed.
  MIN_TERM_LENGTH = 3

  # Safety valve against an unbounded knowledge base, NOT a cost control.
  #
  # This was originally 8 — which silently became a real cap the moment the
  # knowledge base grew past 8 entries, truncating the tail. Because entries
  # carry no `position`, the tail is just insertion order, so the last entry
  # in the YAML got dropped first: the contact details, which the system
  # prompt explicitly tells the model to point visitors toward.
  #
  # Measured at 13 entries: the entire knowledge base is ~770 words / ~1,300
  # tokens, and the full system prompt around it ~1,400. That is negligible
  # for any current model, so there is no reason to truncate a person-scale
  # knowledge base at all. This number exists only so the prompt can't grow
  # without limit if the base ever balloons.
  #
  # knowledge_retriever_test.rb asserts this stays >= the shipped seed file's
  # entry count, so outgrowing it fails loudly instead of silently degrading.
  MAX_ENTRIES = 25

  def initialize(scope: KnowledgeEntry.all)
    @scope = scope
  end

  # Returns entries to ground the answer in, most relevant first, capped at
  # MAX_ENTRIES. Never returns fewer than the whole base while it fits: the
  # model always sees everything known about Daffa, ordered by relevance.
  def retrieve(question)
    entries = @scope.ordered.to_a
    return [] if entries.empty?

    terms = terms_in(question)
    return entries.first(MAX_ENTRIES) if terms.empty?

    # Index is an explicit tiebreaker rather than a reliance on sort stability
    # — Ruby does not guarantee sort_by is stable, so equal scores could
    # otherwise reorder between identical requests. Falling back to `ordered`'s
    # position keeps repeated questions deterministic.
    entries.each_with_index
           .sort_by { |entry, index| [ -score(entry, terms), index ] }
           .first(MAX_ENTRIES)
           .map(&:first)
  end

  private
    def terms_in(question)
      question.to_s.downcase.scan(/[a-z0-9+#.]+/)
              .reject { |w| w.length < MIN_TERM_LENGTH || STOP_WORDS.include?(w) }
              .uniq
    end

    # Title and category matches weigh more than body matches: an entry
    # titled "Tech Stack" should beat one that merely mentions a stack in
    # passing.
    def score(entry, terms)
      title = entry.title.to_s.downcase
      category = entry.category.to_s.downcase
      content = entry.content.to_s.downcase

      terms.sum do |term|
        (title.include?(term) ? 3 : 0) +
          (category.include?(term) ? 2 : 0) +
          (content.include?(term) ? 1 : 0)
      end
    end
end
