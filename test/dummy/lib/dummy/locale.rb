# frozen_string_literal: true

module Dummy
  # Dummy-only locale switch so review shots can use ?locale=fr and a saved
  # profile locale. Hosts that install Recording Studio Internationalization
  # should use that gem instead of copying this.
  module Locale
    AVAILABLE = %i[en fr].freeze

    module_function

    def from_request(request)
      query = Rack::Utils.parse_nested_query(request.env["QUERY_STRING"].to_s)
      requested = query["locale"].presence || profile_locale(request)
      sanitize(requested)
    end

    def sanitize(value)
      code = value.to_s.strip.to_sym
      AVAILABLE.include?(code) ? code : I18n.default_locale
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
      I18n.with_locale(Dummy::Locale.from_request(request)) { @app.call(env) }
    end
  end
end
