# frozen_string_literal: true

require "test_helper"

class ReturnToTest < Minitest::Test
  def test_accepts_a_relative_path
    assert_equal "/messages/42/join", accept("/messages/42/join")
    assert_equal "/messages/42/join?token=abc", accept("/messages/42/join?token=abc")
    assert_equal "/a?t=ab//cd+ef==", accept("/a?t=ab//cd+ef==")
    assert_equal "/a?x=foo:bar&e=a@b", accept("/a?x=foo:bar&e=a@b")
    assert_equal "/a#ab//cd", accept("/a#ab//cd")
    assert_equal "/okay", accept("/%6Fkay")
    assert_equal "/#{'a' * 2047}", accept("/#{'a' * 2047}")
  end

  def test_drops_unsafe_values
    [
      nil,
      "",
      "   ",
      "https://evil.com",
      "http://evil.com/path",
      "//evil.com",
      "/\\evil.com",
      "javascript:alert(1)",
      "/javascript:alert(1)",
      "/%2F%2Fevil.com",
      "/foo\\bar",
      "/%5Cevil.com",
      "/ok\r\nLocation: https://evil.com",
      "/foo bar",
      "/user@evil.com",
      "/#{'a' * 2048}",
      "/%2f%2fevil.com",
      "/foo\u2215bar",
      "//evil",
      "/\\evil",
      "/a//b",
      "/javascript:x",
      "/%2F%2Fevil",
      "/a?t=%0d%0a",
      "/a?x=a b",
      "/a?x=a\\b",
      "/a?t=a\u2215b",
      "/a#%0a"
    ].each do |raw|
      assert_nil accept(raw), "expected #{raw.inspect} to be dropped"
    end
  end

  def test_remember_keeps_a_safe_path_and_ignores_a_bad_one
    session = {}
    RecordingStudioUser::ReturnTo.remember(session, "/next", popup: "1")

    assert_equal "/next", session["user_return_to"]
    assert_equal true, session["recording_studio_user_auth_popup"]

    RecordingStudioUser::ReturnTo.remember(session, "//evil.com")

    assert_equal "/next", session["user_return_to"]
  end

  def test_remember_rack_reads_the_query_string
    env = { "QUERY_STRING" => "return_to=/next&popup=1", "rack.session" => {} }
    RecordingStudioUser::ReturnTo.remember_rack(env)

    assert_equal "/next", env["rack.session"]["user_return_to"]
    assert_equal true, env["rack.session"]["recording_studio_user_auth_popup"]
  end

  def test_with_query_omits_an_unsafe_path
    assert_equal "/users/sign_in?popup=1",
                 RecordingStudioUser::ReturnTo.with_query("/users/sign_in", return_to: "//evil.com", popup: true)
    assert_equal "/users/sign_in",
                 RecordingStudioUser::ReturnTo.with_query("/users/sign_in", return_to: nil, popup: false)

    path = RecordingStudioUser::ReturnTo.with_query("/users/sign_in", return_to: "/next")
    query = Rack::Utils.parse_query(path.split("?", 2).last)

    assert_equal "/next", query["return_to"]
  end

  private

  def accept(raw)
    RecordingStudioUser::ReturnTo.accept(raw)
  end
end
