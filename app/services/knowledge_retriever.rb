# The "R" in RAG, kept deliberately simple: CLAUDE.md specifies
# "simple keyword-based retrieval", not embeddings. The knowledge base is a
# few dozen short entries about one person, so scoring beats similarity
# search here — and it needs no extra service, gem, or vector column.
class KnowledgeRetriever
  # Words that would match nearly every entry and so carry no signal.
  STOP_WORDS = %w[
    a an and are as at be but by for from has have how i in is it its of on or
    that the this to was what when where which who why with you your daffa
  ].to_set.freeze

  # Anything shorter is noise ("is", "do") once stop words are removed.
  MIN_TERM_LENGTH = 3

  # Caps how much context reaches the prompt. Groq's free tier bills by
  # tokens, and a bloated prompt also dilutes the answer.
  MAX_ENTRIES = 8

  def initialize(scope: KnowledgeEntry.all)
    @scope = scope
  end

  # Returns the entries most likely to be relevant to `question`, best first.
  # Falls back to everything (capped) when nothing matches, so the model
  # always has *some* grounding rather than answering from thin air.
  def retrieve(question)
    entries = @scope.ordered.to_a
    return entries.first(MAX_ENTRIES) if entries.empty?

    terms = terms_in(question)
    return entries.first(MAX_ENTRIES) if terms.empty?

    scored = entries.map { |entry| [ entry, score(entry, terms) ] }.reject { |_, s| s.zero? }
    return entries.first(MAX_ENTRIES) if scored.empty?

    # sort_by is stable in Ruby, so equal scores keep `ordered`'s position
    # ordering rather than shuffling between requests.
    scored.sort_by { |_, s| -s }.first(MAX_ENTRIES).map(&:first)
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
