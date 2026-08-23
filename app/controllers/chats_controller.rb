class ChatsController < ApplicationController
  # Visitor-facing — see PagesController for why this opt-out is required.
  allow_unauthenticated_access

  # Per-IP cap, from CLAUDE.md's rate limiting strategy. Rails 8's built-in
  # rate_limit is backed by Solid Cache, which this app already runs.
  rate_limit to: 20, within: 1.hour, only: :create, with: -> { render_rate_limited }

  # Per-session cap, also from CLAUDE.md. Independent of the per-IP limit:
  # this one stops a single visitor burning the shared quota in one sitting,
  # and resets when their browser session does.
  SESSION_QUESTION_LIMIT = 10

  # Long enough for a real question, short enough that nobody pastes an
  # essay into a prompt we pay tokens for.
  MAX_QUESTION_LENGTH = 500

  LIMIT_REACHED_MESSAGE = "You've reached the question limit for now. For more details about me, " \
                          "feel free to reach out directly via email or LinkedIn below.".freeze

  UNAVAILABLE_MESSAGE = "The AI assistant is temporarily unavailable. Please try again later " \
                        "or contact me directly.".freeze

  BLANK_MESSAGE = "Ask me something about Daffa and I'll do my best to answer.".freeze

  def create
    @question = params[:message].to_s.strip.truncate(MAX_QUESTION_LENGTH)

    return render_reply(BLANK_MESSAGE, echo_question: false) if @question.blank?
    return render_rate_limited if session_questions_exhausted?

    increment_session_questions
    render_reply(chat_service.respond(@question))
  rescue ChatService::RateLimited => e
    Rails.logger.warn("[chat] provider rate limited: #{e.message}")
    render_reply(LIMIT_REACHED_MESSAGE)
  rescue ChatService::Unavailable => e
    # The visitor never sees this detail — only the generic copy above.
    Rails.logger.error("[chat] unavailable: #{e.message}")
    render_reply(UNAVAILABLE_MESSAGE)
  end

  private
    def chat_service
      @chat_service ||= ChatService.new
    end

    def session_questions_asked
      session[:chat_questions_asked].to_i
    end

    def session_questions_exhausted?
      session_questions_asked >= SESSION_QUESTION_LIMIT
    end

    def increment_session_questions
      session[:chat_questions_asked] = session_questions_asked + 1
    end

    # Turbo Stream appends both bubbles in one response, so the visitor's own
    # message and the answer land together without any client-side rendering.
    # The HTML fallback (no-JS, or a direct POST) re-renders the landing page.
    def render_reply(answer, echo_question: true)
      @answer = answer
      @echo_question = echo_question

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to root_path(anchor: "chat") }
      end
    end

    def render_rate_limited
      render_reply(LIMIT_REACHED_MESSAGE)
    end
end
