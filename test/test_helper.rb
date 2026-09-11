ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Runs the block with `key` removed from ENV, then restores it.
    #
    # dotenv-rails loads .env in the test environment, so any test asserting
    # default/unconfigured behaviour has to clear the variable explicitly —
    # otherwise it passes in CI (no .env) while doing something entirely
    # different on a machine that has one, up to and including calling a live
    # API. Tests run in separate processes under parallelize, so mutating ENV
    # here is process-local.
    def without_env(key)
      had_key = ENV.key?(key)
      original = ENV.delete(key)

      yield
    ensure
      ENV[key] = original if had_key
    end
  end
end
