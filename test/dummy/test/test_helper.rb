# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require "devise"

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
