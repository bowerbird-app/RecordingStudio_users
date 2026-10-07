# frozen_string_literal: true

module Dummy
  # Dummy-only locale switch so review shots can use ?locale=fr and a saved
  # profile locale. Hosts that install Recording Studio Internationalization
  # should use that gem instead of copying this.
  module Locale
    AVAILABLE = %i[en fr].freeze
    COOKIE = "dummy_locale"

    module_function

    def from_request(request)
      sanitize(
        query_locale(request) ||
          posted_locale(request) ||
          profile_locale(request) ||
          request.cookies[COOKIE]
      )
    end

    def sanitize(value)
      code = value.to_s.strip.to_sym
      AVAILABLE.include?(code) ? code : I18n.default_locale
    end

    def query_locale(request)
      Rack::Utils.parse_nested_query(request.env["QUERY_STRING"].to_s)["locale"].presence
    end

    def posted_locale(request)
      return unless %w[POST PUT PATCH].include?(request.request_method)

      value = request.params.dig("user", "locale")
      return if value.nil?

      value.to_s.strip.presence || I18n.default_locale.to_s
    end

    def profile_locale(request)
      user = request.env["warden"]&.user
      return if user.blank?

      RecordingStudioUser.profile_for(user)&.locale
    rescue StandardError
      nil
    end
  end

  class LocaleMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      locale = Dummy::Locale.from_request(request)
      status, headers, body = I18n.with_locale(locale) { @app.call(env) }
      persist_locale(headers, locale)
      [status, headers, body]
    end

    private

    def persist_locale(headers, locale)
      Rack::Utils.set_cookie_header!(
        headers,
        Dummy::Locale::COOKIE,
        value: locale.to_s,
        path: "/",
        same_site: :lax
      )
    end
  end
end
