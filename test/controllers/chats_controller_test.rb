require "test_helper"
require "minitest/mock"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  # Stands in for ChatService so no test ever reaches a real provider.
  class FakeService
    attr_reader :questions

    def initialize(answer: "A canned answer.", raises: nil)
      @answer = answer
      @raises = raises
      @questions = []
    end

    def respond(question)
      @questions << question
      raise @raises if @raises

      @answer
    end
  end

  def with_service(service, &block)
    ChatService.stub(:new, service, &block)
  end

  def post_question(message, **options)
    post chat_path, params: { message: message }, as: :turbo_stream, **options
  end

  # Runs the block with `key` removed from ENV, then restores it. Kept public
  # alongside the other helpers on purpose: a `private` section here would sit
  # above later `test` blocks, and since `test` defines methods dynamically,
  # those would become private and silently stop being collected.
  def without_env(key)
    had_key = ENV.key?(key)
    original = ENV.delete(key)

    yield
  ensure
    ENV[key] = original if had_key
  end

  test "answers a question without requiring authentication" do
    with_service(FakeService.new(answer: "He uses Rails.")) do
      post_question("What stack?")
    end

    assert_response :success
    assert_match "He uses Rails.", response.body
  end

  test "echoes the visitor's question back as its own bubble" do
    with_service(FakeService.new) do
      post_question("What stack?")
    end

    # Both bubbles arrive in one Turbo Stream response, so the transcript
    # stays complete without any client-side rendering.
    assert_equal 2, response.body.scan("turbo-stream").size / 2
    assert_match "What stack?", response.body
  end

  test "passes the question through to the service" do
    service = FakeService.new

    with_service(service) { post_question("  What stack?  ") }

    assert_equal [ "What stack?" ], service.questions
  end

  test "truncates an overlong question before spending tokens on it" do
    service = FakeService.new

    with_service(service) { post_question("x" * 5_000) }

    assert_operator service.questions.first.length, :<=, ChatsController::MAX_QUESTION_LENGTH
  end

  test "prompts instead of calling the provider for a blank question" do
    service = FakeService.new

    with_service(service) { post_question("   ") }

    assert_response :success
    assert_empty service.questions, "must not spend a request on an empty question"
    # The rendered body is HTML-escaped, so compare against the escaped copy.
    assert_match ERB::Util.html_escape(ChatsController::BLANK_MESSAGE), response.body
  end

  test "shows the limit message once the session's questions are used up" do
    service = FakeService.new

    with_service(service) do
      ChatsController::SESSION_QUESTION_LIMIT.times { |i| post_question("Question #{i}") }

      assert_equal ChatsController::SESSION_QUESTION_LIMIT, service.questions.size

      post_question("One too many")
    end

    assert_response :success
    assert_match "reached the question limit", response.body
    assert_equal ChatsController::SESSION_QUESTION_LIMIT, service.questions.size,
      "must stop calling the provider once the session limit is reached"
  end

  test "shows the limit message when the provider rate limits us" do
    with_service(FakeService.new(raises: ChatService::RateLimited.new("429 from provider"))) do
      post_question("What stack?")
    end

    assert_response :success
    assert_match "reached the question limit", response.body
    # The provider's own wording must never reach a visitor.
    assert_no_match(/429/, response.body)
  end

  test "shows the unavailable message when the provider is down" do
    with_service(FakeService.new(raises: ChatService::Unavailable.new("HTTP 503: upstream boom"))) do
      post_question("What stack?")
    end

    assert_response :success
    assert_match ChatsController::UNAVAILABLE_MESSAGE, response.body
    assert_no_match(/503/, response.body)
    assert_no_match(/upstream boom/, response.body)
  end

  test "never leaks a raw exception when the service misbehaves entirely" do
    # Exercises the default configuration path with no stubbing at all: a
    # missing API key surfaces as Unavailable from the real ChatService.
    #
    # The key is cleared explicitly rather than assumed absent. dotenv-rails
    # loads .env in the test environment too, so on a machine with a real key
    # configured this test would otherwise call the live provider — slow,
    # flaky, quota-spending, and green in CI while behaving differently
    # locally.
    without_env("GROQ_API_KEY") do
      post_question("What stack?")
    end

    assert_response :success
    assert_match ChatsController::UNAVAILABLE_MESSAGE, response.body
  end

  test "an html post redirects back to the chat section" do
    with_service(FakeService.new) do
      post chat_path, params: { message: "What stack?" }
    end

    assert_redirected_to root_path(anchor: "chat")
  end

  # NOTE: the per-IP limiter (`rate_limit to: 20, within: 1.hour`) is not
  # asserted here. Rails resolves its backing store when the class loads, and
  # the test environment uses `:null_store`, whose `increment` returns nil —
  # so the limiter is a no-op under test regardless of how many requests we
  # make. It's framework behaviour backed by Solid Cache in production; the
  # session-scoped limit above is the part this app implements itself.
end
