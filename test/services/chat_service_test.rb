require "test_helper"
# For Object#stub, used only by the "real Net::HTTP path" tests at the bottom.
require "minitest/mock"

# Contract tests for the OpenAI-compatible /chat/completions API that
# ChatService speaks. No network, no mocking gem: ChatService takes a
# `transport:` callable, so a lambda stands in for Net::HTTP and returns
# canned [status, body] pairs.
#
# Two halves, both of which matter:
#   1. REQUEST  — we send exactly what the contract requires (captured and
#      asserted below). If a provider swap breaks the shape, these fail.
#   2. RESPONSE — we correctly read a well-formed reply, and degrade into our
#      own error types for every documented failure mode (429, 401, 5xx,
#      malformed body, network error).
class ChatServiceTest < ActiveSupport::TestCase
  # A verbatim-shaped success body, per the documented contract.
  def success_body(content = "Daffa works mainly in Ruby on Rails.")
    {
      id: "chatcmpl-abc123",
      object: "chat.completion",
      created: 1_730_241_104,
      model: "openai/gpt-oss-120b",
      choices: [
        {
          index: 0,
          message: { role: "assistant", content: content },
          finish_reason: "stop"
        }
      ],
      usage: { prompt_tokens: 18, completion_tokens: 12, total_tokens: 30 }
    }.to_json
  end

  # The documented provider error envelope: { "error": { message, type } }.
  def error_body(message = "Rate limit reached", type = "rate_limit_exceeded")
    { error: { message: message, type: type } }.to_json
  end

  # Records what ChatService sent, so the request half of the contract can be
  # asserted. Returns whatever [status, body] it was constructed with.
  class RecordingTransport
    attr_reader :uri, :body, :headers, :calls

    def initialize(status: 200, response_body: "{}")
      @status = status
      @response_body = response_body
      @calls = 0
    end

    def call(uri, body, headers)
      @uri = uri
      @body = body
      @headers = headers
      @calls += 1
      [ @status, @response_body ]
    end

    def parsed_body
      JSON.parse(@body)
    end
  end

  def service(transport:, **overrides)
    ChatService.new(
      api_key: "test-key",
      retriever: StubRetriever.new,
      transport: transport,
      **overrides
    )
  end

  # Stands in for KnowledgeRetriever so these tests never touch the database
  # and the prompt contents stay predictable.
  class StubRetriever
    Entry = Struct.new(:line) do
      def to_context_line
        line
      end
    end

    def initialize(lines: [ "[skills] Stack: Ruby on Rails." ])
      @lines = lines
    end

    def retrieve(_question)
      @lines.map { |l| Entry.new(l) }
    end
  end

  # ---------------------------------------------------------------- request

  test "posts to the chat completions path on the configured base url" do
    transport = RecordingTransport.new(response_body: success_body)

    service(transport: transport, base_url: "https://api.example.com/v1").respond("What stack?")

    assert_equal "https://api.example.com/v1/chat/completions", transport.uri.to_s
  end

  test "tolerates a base url with a trailing slash" do
    transport = RecordingTransport.new(response_body: success_body)

    service(transport: transport, base_url: "https://api.example.com/v1/").respond("What stack?")

    assert_equal "https://api.example.com/v1/chat/completions", transport.uri.to_s
  end

  test "sends bearer auth and a json content type" do
    transport = RecordingTransport.new(response_body: success_body)

    service(transport: transport).respond("What stack?")

    assert_equal "Bearer test-key", transport.headers["Authorization"]
    assert_equal "application/json", transport.headers["Content-Type"]
  end

  # LLM_MODEL is cleared explicitly: it's a documented .env override, so on a
  # machine that sets it this would otherwise assert the wrong value.
  test "falls back to the default model when none is configured" do
    transport = RecordingTransport.new(response_body: success_body)

    without_env("LLM_MODEL") do
      ChatService.new(api_key: "k", retriever: StubRetriever.new, transport: transport).respond("What stack?")
    end

    assert_equal ChatService::DEFAULT_MODEL, transport.parsed_body["model"]
  end

  test "falls back to the default base url when none is configured" do
    transport = RecordingTransport.new(response_body: success_body)

    without_env("LLM_BASE_URL") do
      ChatService.new(api_key: "k", retriever: StubRetriever.new, transport: transport).respond("What stack?")
    end

    assert_equal "#{ChatService::DEFAULT_BASE_URL}/chat/completions", transport.uri.to_s
  end

  test "sends the model and a system-then-user message pair" do
    transport = RecordingTransport.new(response_body: success_body)

    service(transport: transport, model: "some-model").respond("What stack?")

    body = transport.parsed_body
    assert_equal "some-model", body["model"]
    assert_equal %w[system user], body["messages"].map { |m| m["role"] }
    assert_equal "What stack?", body["messages"].last["content"]
  end

  test "grounds the system prompt in the retrieved knowledge" do
    transport = RecordingTransport.new(response_body: success_body)
    retriever = StubRetriever.new(lines: [ "[skills] Stack: Ruby on Rails.", "[personal] Based in Depok." ])

    ChatService.new(api_key: "k", retriever: retriever, transport: transport).respond("Where?")

    system_prompt = transport.parsed_body["messages"].first["content"]
    assert_includes system_prompt, "[skills] Stack: Ruby on Rails."
    assert_includes system_prompt, "[personal] Based in Depok."
    # The guardrail that keeps the bot on-topic must actually be sent.
    assert_includes system_prompt, "Only answer questions related to Daffa Pradana."
  end

  test "uses max_completion_tokens rather than the deprecated max_tokens" do
    transport = RecordingTransport.new(response_body: success_body)

    service(transport: transport).respond("What stack?")

    body = transport.parsed_body
    assert body.key?("max_completion_tokens"), "expected max_completion_tokens in #{body.keys.inspect}"
    assert_not body.key?("max_tokens")
  end

  test "strips surrounding whitespace from the question it sends" do
    transport = RecordingTransport.new(response_body: success_body)

    service(transport: transport).respond("  What stack?  ")

    assert_equal "What stack?", transport.parsed_body["messages"].last["content"]
  end

  # --------------------------------------------------------------- response

  test "returns the assistant content from a well-formed response" do
    transport = RecordingTransport.new(response_body: success_body("He uses Rails."))

    assert_equal "He uses Rails.", service(transport: transport).respond("What stack?")
  end

  test "strips whitespace from the returned answer" do
    transport = RecordingTransport.new(response_body: success_body("\n  He uses Rails.\n "))

    assert_equal "He uses Rails.", service(transport: transport).respond("What stack?")
  end

  # ----------------------------------------------------------------- errors

  test "raises RateLimited on HTTP 429" do
    transport = RecordingTransport.new(status: 429, response_body: error_body)

    error = assert_raises(ChatService::RateLimited) do
      service(transport: transport).respond("What stack?")
    end

    # The provider's own reason is preserved for the logs.
    assert_includes error.message, "Rate limit reached"
  end

  test "raises Unavailable on HTTP 401" do
    transport = RecordingTransport.new(status: 401, response_body: error_body("Invalid API Key", "invalid_api_key"))

    error = assert_raises(ChatService::Unavailable) do
      service(transport: transport).respond("What stack?")
    end

    assert_includes error.message, "401"
    assert_includes error.message, "Invalid API Key"
  end

  test "raises Unavailable on a 5xx" do
    [ 500, 502, 503 ].each do |status|
      transport = RecordingTransport.new(status: status, response_body: error_body("upstream boom", "internal_server_error"))

      error = assert_raises(ChatService::Unavailable, "expected #{status} to be Unavailable") do
        service(transport: transport).respond("What stack?")
      end

      assert_includes error.message, status.to_s
    end
  end

  test "raises Unavailable when an error body is not json" do
    transport = RecordingTransport.new(status: 502, response_body: "<html>Bad Gateway</html>")

    error = assert_raises(ChatService::Unavailable) do
      service(transport: transport).respond("What stack?")
    end

    assert_includes error.message, "502"
  end

  test "raises Unavailable when a 200 body is not json" do
    transport = RecordingTransport.new(response_body: "not json at all")

    assert_raises(ChatService::Unavailable) do
      service(transport: transport).respond("What stack?")
    end
  end

  test "raises Unavailable when a 200 body has no choices" do
    transport = RecordingTransport.new(response_body: { id: "x", choices: [] }.to_json)

    assert_raises(ChatService::Unavailable) do
      service(transport: transport).respond("What stack?")
    end
  end

  test "raises Unavailable when the assistant content is blank" do
    transport = RecordingTransport.new(response_body: success_body(""))

    assert_raises(ChatService::Unavailable) do
      service(transport: transport).respond("What stack?")
    end
  end

  test "raises Unavailable when the transport itself fails" do
    exploding = ->(_uri, _body, _headers) { raise ChatService::Unavailable, "Timeout::Error: execution expired" }

    assert_raises(ChatService::Unavailable) do
      service(transport: exploding).respond("What stack?")
    end
  end

  # ------------------------------------------------- the real Net::HTTP path
  #
  # Every test above injects a transport, which would leave the default
  # Net::HTTP implementation — and its error handling — completely uncovered.
  # These stub Net::HTTP.start instead, so the shipped transport is what runs.

  # Builds a real Net::HTTPResponse carrying `body`, without a socket.
  def http_response(klass, code, body)
    klass.new("1.1", code, "").tap do |response|
      response.instance_variable_set(:@body, body)
      response.instance_variable_set(:@read, true)
    end
  end

  # Net::HTTP.start is called with a block that receives the connection, so
  # the stub needs a stand-in to yield. Minitest passes any extra args to the
  # block, and returns the stub value itself as start's result.
  def with_stubbed_http(response, &test)
    connection = Object.new
    connection.define_singleton_method(:post) { |*| response }

    Net::HTTP.stub(:start, response, connection, &test)
  end

  test "the default transport parses a real http response" do
    response = http_response(Net::HTTPOK, "200", success_body("From the wire."))

    with_stubbed_http(response) do
      answer = ChatService.new(api_key: "k", retriever: StubRetriever.new).respond("What stack?")
      assert_equal "From the wire.", answer
    end
  end

  test "the default transport collapses network failures into Unavailable" do
    # Each of these is a plausible real-world failure that must not escape as
    # itself — ChatsController only rescues this class's own errors.
    [
      Timeout::Error.new("execution expired"),
      Errno::ECONNREFUSED.new,
      Errno::ECONNRESET.new,
      SocketError.new("getaddrinfo: Name or service not known"),
      OpenSSL::SSL::SSLError.new("certificate verify failed"),
      IOError.new("closed stream")
    ].each do |failure|
      raising = ->(*) { raise failure }

      Net::HTTP.stub(:start, raising) do
        error = assert_raises(ChatService::Unavailable, "#{failure.class} should become Unavailable") do
          ChatService.new(api_key: "k", retriever: StubRetriever.new).respond("What stack?")
        end

        assert_includes error.message, failure.class.name
      end
    end
  end

  test "the default transport surfaces a real 429 as RateLimited" do
    response = http_response(Net::HTTPTooManyRequests, "429", error_body)

    with_stubbed_http(response) do
      assert_raises(ChatService::RateLimited) do
        ChatService.new(api_key: "k", retriever: StubRetriever.new).respond("What stack?")
      end
    end
  end

  # ------------------------------------------------------------ guard rails

  test "raises Unavailable without calling the provider when no api key is set" do
    transport = RecordingTransport.new(response_body: success_body)

    assert_raises(ChatService::Unavailable) do
      ChatService.new(api_key: nil, retriever: StubRetriever.new, transport: transport).respond("What stack?")
    end

    assert_equal 0, transport.calls, "must not spend a request without credentials"
  end

  test "treats a blank api key the same as a missing one" do
    transport = RecordingTransport.new(response_body: success_body)

    assert_raises(ChatService::Unavailable) do
      ChatService.new(api_key: "   ", retriever: StubRetriever.new, transport: transport).respond("What stack?")
    end

    assert_equal 0, transport.calls
  end

  test "raises Unavailable without calling the provider for a blank question" do
    transport = RecordingTransport.new(response_body: success_body)

    assert_raises(ChatService::Unavailable) do
      service(transport: transport).respond("   ")
    end

    assert_equal 0, transport.calls, "must not spend a request on an empty question"
  end
end
