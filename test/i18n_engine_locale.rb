# frozen_string_literal: true

# Load gem English only inside tests that need it (not from test_helper).
module I18nEngineLocale
  ENGINE_EN_LOCALE = File.expand_path("../config/locales/en.yml", __dir__)

  def with_engine_english_locale
    previous = I18n.backend
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.load_translations(ENGINE_EN_LOCALE)
    yield
  ensure
    I18n.backend = previous
  end
end
