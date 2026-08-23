require "net/http"
require "json"

# Talks to any LLM provider that speaks the OpenAI-compatible
# /chat/completions contract — Groq is only the default. That contract is:
#
#   POST {base_url}/chat/completions
#   Authorization: Bearer <api_key>
#   Content-Type: application/json
#
#   -> { "model": "...", "messages": [{ "role": ..., "content": ... }, ...] }
#   <- 200 { "choices": [{ "message": { "role": "assistant",
#                                       "content": "..." },
#                          "finish_reason": "stop" }],
#            "usage": { "prompt_tokens": 1, "completion_tokens": 2, ... } }
#   <- 4xx/5xx { "error": { "message": "...", "type": "..." } }
#
# Groq, OpenRouter, Together, Cerebras and Gemini's compat endpoint all
# implement this, so switching providers is a base_url/model/api_key change
# rather than a rewrite. Nothing Groq-specific belongs in this class.
class ChatService
  # Provider hit its quota (HTTP 429). Distinct from Unavailable because the
  # visitor-facing copy differs — see ChatsController.
  class RateLimited < StandardError; end

  # Anything else we can't recover from: auth failure, 5xx, network error,
  # unparsable or malformed body, or no API key configured. Deliberately one
  # class: the visitor sees the same message regardless, and the distinction
  # only matters in logs.
  class Unavailable < StandardError; end

  DEFAULT_BASE_URL = "https://api.groq.com/openai/v1"

  # Providers retire model names, so treat this as a moving target rather than
  # a constant of nature: Groq dropped `llama-3.3-70b-versatile` (CLAUDE.md's
  # original pick) and now answers 404 for it. Override with LLM_MODEL — no
  # code change needed — and check the live list with:
  #
  #   curl -H "Authorization: Bearer $GROQ_API_KEY" \
  #        https://api.groq.com/openai/v1/models
  #
  # gpt-oss-20b is the cheaper/faster swap and handles this workload fine;
  # 120b was chosen for slightly tighter adherence to the system prompt's
  # "only answer questions about Daffa" and "don't invent facts" rules.
  DEFAULT_MODEL = "openai/gpt-oss-120b"

  # Low temperature: this bot answers questions of fact about one person, so
  # determinism is worth more than variety.
  DEFAULT_TEMPERATURE = 0.3

  # CLAUDE.md asks for 2-4 sentence answers; this is a hard backstop in case
  # the model ignores the instruction.
  DEFAULT_MAX_TOKENS = 500

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 20

  # Every transport-level failure is collapsed into Unavailable, so callers
  # only ever handle this class's own two error types.
  NETWORK_ERRORS = [
    Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
    SocketError, OpenSSL::SSL::SSLError, IOError
  ].freeze

  # Verbatim from CLAUDE.md's "System Prompt (for Groq)" section. %{knowledge}
  # is the only interpolation.
  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are an AI assistant on Daffa Pradana's personal portfolio website.
    Your ONLY purpose is to answer questions about Daffa — his professional
    experience, skills, projects, education, and background.

    Rules:
    1. Only answer questions related to Daffa Pradana.
    2. If asked about anything unrelated to Daffa, politely decline and redirect.
    3. Keep answers concise and professional (2-4 sentences max).
    4. If you don't have the information, say so honestly.
    5. Encourage visitors to contact Daffa directly for detailed inquiries.
    6. Never make up information that isn't provided in the context below.

    Here is everything you know about Daffa:
    %{knowledge}
  PROMPT

  # `transport` is the seam that makes this testable without a mocking gem:
  # a callable taking (uri, body_json_string, headers_hash) and returning
  # [status_integer, response_body_string]. Production uses Net::HTTP; tests
  # inject a lambda returning canned responses. See
  # test/services/chat_service_test.rb.
  def initialize(api_key: ENV["GROQ_API_KEY"],
                 base_url: ENV.fetch("LLM_BASE_URL", DEFAULT_BASE_URL),
                 model: ENV.fetch("LLM_MODEL", DEFAULT_MODEL),
                 retriever: KnowledgeRetriever.new,
                 transport: nil)
    @api_key = api_key.presence
    @base_url = base_url.to_s.chomp("/")
    @model = model
    @retriever = retriever
    @transport = transport || method(:http_transport)
  end

  # Returns the assistant's answer as a String.
  # Raises RateLimited or Unavailable — never leaks a raw provider error.
  def respond(question)
    raise Unavailable, "no API key configured" if @api_key.blank?
    raise Unavailable, "blank question" if question.blank?

    status, body = @transport.call(endpoint_uri, request_body(question).to_json, request_headers)

    case status
    when 200 then extract_answer(body)
    when 429 then raise RateLimited, provider_error(body) || "provider rate limit"
    else raise Unavailable, "HTTP #{status}: #{provider_error(body) || "unexpected response"}"
    end
  end

  private
    def endpoint_uri
      URI.parse("#{@base_url}/chat/completions")
    end

    def request_headers
      {
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type" => "application/json"
      }
    end

    def request_body(question)
      {
        model: @model,
        messages: [
          { role: "system", content: system_prompt_for(question) },
          { role: "user", content: question.to_s.strip }
        ],
        temperature: DEFAULT_TEMPERATURE,
        # `max_completion_tokens`, not the deprecated `max_tokens` — the
        # current name in the OpenAI-compatible spec Groq implements.
        max_completion_tokens: DEFAULT_MAX_TOKENS
      }
    end

    # Retrieval happens per question, not once at initialize, because which
    # entries are relevant depends on what was asked.
    def system_prompt_for(question)
      entries = @retriever.retrieve(question)
      knowledge = if entries.any?
        entries.map(&:to_context_line).join("\n")
      else
        "(No knowledge entries are available.)"
      end

      format(SYSTEM_PROMPT, knowledge: knowledge)
    end

    def extract_answer(body)
      payload = JSON.parse(body)
      answer = payload.dig("choices", 0, "message", "content")

      raise Unavailable, "response contained no answer" if answer.blank?

      answer.strip
    rescue JSON::ParserError
      raise Unavailable, "provider returned unparsable JSON"
    end

    # Providers put the human-readable reason at error.message. Never
    # surfaced to visitors — it goes into the exception for the logs.
    def provider_error(body)
      JSON.parse(body.to_s).dig("error", "message")
    rescue JSON::ParserError, TypeError
      nil
    end

    def http_transport(uri, body_json, headers)
      response = Net::HTTP.start(uri.host, uri.port,
                                use_ssl: uri.scheme == "https",
                                open_timeout: OPEN_TIMEOUT,
                                read_timeout: READ_TIMEOUT) do |http|
        http.post(uri.path, body_json, headers)
      end

      [ response.code.to_i, response.body ]
    rescue *NETWORK_ERRORS => e
      raise Unavailable, "#{e.class}: #{e.message}"
    end
end
