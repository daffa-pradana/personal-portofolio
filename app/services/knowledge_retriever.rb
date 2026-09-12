# The "R" in RAG, kept deliberately simple: CLAUDE.md specifies
# "simple keyword-based retrieval", not embeddings. The knowledge base is a
# few dozen short entries about one person, so scoring beats similarity
# search here — and it needs no extra service, gem, or vector column.
#
# Scoring ranks entries; it never excludes a zero-scoring one outright — that
# was tried and was actively harmful at this scale: keyword overlap between a
# short question and a short entry is sparse, so "What projects has Daffa
# worked on?" scored only 2 of 13 entries and "is he any good?" scored 1,
# starving the model of context.
#
# CAP then trims the ranked list to a prompt-sized slice, with FLOOR_CATEGORY
# guaranteed a seat even if its score didn't earn one — the system prompt
# tells the model to point visitors to contact info, so it must always be
# reachable. This is the top-N-plus-floor design deferred in PROGRESS.md
# after "send the whole base" (measured ~1,439 tokens/question) turned out to
# be overkill once the base grew past a handful of entries.
class KnowledgeRetriever
  # Words that would match nearly every entry and so carry no signal.
  STOP_WORDS = %w[
    a an and are as at be but by for from has have how i in is it its of on or
    that the this to was what when where which who why with you your daffa
  ].to_set.freeze

  # Anything shorter is noise ("is", "do") once stop words are removed.
  MIN_TERM_LENGTH = 3

  # How many entries actually reach the prompt. 6 was the number logged in
  # PROGRESS.md's deferred plan — small enough to matter for token cost
  # (measured: sending all 13 averaged ~1,439 tokens/question against Groq's
  # free-tier 8K TPM), generous enough that the top-ranked matches for a
  # real question all fit alongside the guaranteed floor entry below.
  CAP = 6

  # Always occupies one of the CAP seats, regardless of score, because the
  # system prompt is told to redirect visitors to contact info — an answer
  # that can't cite it defeats that instruction. If more than one entry ever
  # shares this category, the highest-ranked one wins the seat.
  FLOOR_CATEGORY = "contact"

  def initialize(scope: KnowledgeEntry.all)
    @scope = scope
  end

  # Returns up to CAP entries to ground the answer in, most relevant first,
  # with FLOOR_CATEGORY's best match always included.
  def retrieve(question)
    entries = @scope.ordered.to_a
    return [] if entries.empty?

    terms = terms_in(question)

    # Index is an explicit tiebreaker rather than a reliance on sort stability
    # — Ruby does not guarantee sort_by is stable, so equal scores could
    # otherwise reorder between identical requests. With no terms (blank
    # question, or only stop words) every score is 0, so this reduces to
    # `ordered`'s curated position — no separate blank-question case needed.
    ranked = entries.each_with_index
                    .sort_by { |entry, index| [ -score(entry, terms), index ] }
                    .map(&:first)

    top = ranked.first(CAP)
    floor_entry = ranked.find { |entry| entry.category.to_s.casecmp?(FLOOR_CATEGORY) }

    if floor_entry && !top.include?(floor_entry)
      top = top.first(CAP - 1) + [ floor_entry ]
    end

    top
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
