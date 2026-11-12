# frozen_string_literal: true

module RecordingStudioUser
  # One parser for a post-auth return path. Anything unsafe becomes nil.
  module ReturnTo
    SESSION_KEY = "user_return_to"
    POPUP_KEY = "recording_studio_user_auth_popup"
    MAX_LENGTH = 2048
    UNICODE_SEPARATORS = ["\u2215", "\u2044", "\uFF0F", "\uFF3C", "\uFE68", "\u2216"].freeze

    module_function

    def accept(raw)
      decoded = decoded_path(raw)
      return unless decoded
      return unless safe_path?(raw) && safe_path?(decoded)

      decoded
    end

    def remember(session, raw_return_to, popup: nil)
      return unless session

      accepted = accept(raw_return_to)
      session[SESSION_KEY] = accepted if accepted
      session[POPUP_KEY] = true if popup.to_s == "1"
    end

    def remember_rack(env)
      session = env["rack.session"]
      return unless session

      query = Rack::Utils.parse_query(env["QUERY_STRING"].to_s)
      remember(session, query["return_to"], popup: query["popup"])
    end

    def popup?(session)
      session && session[POPUP_KEY] == true
    end

    def clear_popup!(session)
      session&.delete(POPUP_KEY)
    end

    def with_query(path, return_to: nil, popup: false)
      query = query_pairs(return_to, popup)
      return path if query.empty?

      joiner = path.include?("?") ? "&" : "?"
      "#{path}#{joiner}#{Rack::Utils.build_query(query)}"
    end

    def auth_path(screen, return_to: nil, popup: false)
      with_query(screen_path(screen), return_to: return_to, popup: popup)
    end

    def screen_path(screen)
      helpers = Rails.application.routes.url_helpers
      case screen.to_sym
      when :sign_in then helpers.new_user_session_path
      when :sign_up then helpers.new_user_registration_path
      else raise ArgumentError, "auth screen must be :sign_in or :sign_up"
      end
    end

    # Decode once. A second pass would treat %252F%252F as a protocol-relative URL.
    def decoded_path(raw)
      return unless raw.is_a?(String)
      return if raw.empty? || raw.length > MAX_LENGTH

      decoded = percent_decode(raw)
      return if decoded.nil? || decoded.empty? || decoded.length > MAX_LENGTH

      decoded
    end

    def safe_path?(value)
      return false unless value.start_with?("/")
      return false if value.start_with?("//", "/\\")

      path, rest = path_and_rest(value)
      return false if forbidden_path_character?(path)
      return false if rest && forbidden_rest_character?(rest)

      true
    end

    def path_and_rest(value)
      cut = value.index(/[?#]/)
      return [value, nil] unless cut

      [value[0, cut], value[(cut + 1)..]]
    end

    def forbidden_path_character?(value)
      value.match?(%r{//|\\|[[:cntrl:]]|[[:space:]]|@}) ||
        value.match?(/[a-zA-Z][a-zA-Z0-9+.-]*:/) ||
        unicode_separator?(value)
    end

    def forbidden_rest_character?(value)
      value.match?(/\\|[[:cntrl:]]|[[:space:]]/) || unicode_separator?(value)
    end

    def unicode_separator?(value)
      UNICODE_SEPARATORS.any? { |mark| value.include?(mark) }
    end

    def percent_decode(value)
      decoded = value.b.gsub(/%([0-9A-Fa-f]{2})/) { [Regexp.last_match(1)].pack("H*") }
      decoded.force_encoding(Encoding::UTF_8)
      decoded.valid_encoding? ? decoded : nil
    end

    def query_pairs(return_to, popup)
      pairs = {}
      accepted = accept(return_to)
      pairs["return_to"] = accepted if accepted
      pairs["popup"] = "1" if popup
      pairs
    end
  end
end
