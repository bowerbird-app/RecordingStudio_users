# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
require "rails"
require "recording_studio_user"

I18n.available_locales = %i[en]
I18n.default_locale = :en

# Gem unit tests do not boot the Rails engine, so engine `config/locales`
# paths never enter I18n. Load English into the backend without mutating
# `I18n.load_path` (wave-2: no explicit load_path appenders).
ENGINE_EN_LOCALE = File.expand_path("../config/locales/en.yml", __dir__)
I18n.backend.load_translations(ENGINE_EN_LOCALE)
