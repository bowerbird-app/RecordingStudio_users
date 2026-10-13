# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
require "rails"
require "recording_studio_user"

I18n.available_locales = %i[en]
I18n.default_locale = :en
