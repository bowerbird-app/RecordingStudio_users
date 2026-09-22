# frozen_string_literal: true

require "test_helper"
require File.expand_path("../app/helpers/recording_studio_user/auth_terms_notice_helper.rb", __dir__)

class AuthTermsNoticeHelperTest < Minitest::Test
  class View
    include RecordingStudioUser::AuthTermsNoticeHelper
  end

  def setup
    remove_tnc_constant!
  end

  def teardown
    remove_tnc_constant!
  end

  def test_extra_fields_calls_soft_notice_helper
    extra_fields = File.read(
      File.expand_path("../app/views/recording_studio_user/auth/registrations/_extra_fields.html.erb", __dir__)
    )

    assert_includes extra_fields, "recording_studio_user_signup_terms_notice"
    refute_match(/By continuing|agreed|checkbox/i, extra_fields)
  end

  def test_notice_is_noop_without_tnc
    refute defined?(RecordingStudioTermsAndConditions)
    assert_nil View.new.recording_studio_user_signup_terms_notice
  end

  def test_notice_is_noop_when_no_live_terms_are_pending
    stub_tnc(pending: [])
    view = view_with_tnc_helpers

    assert_nil view.recording_studio_user_signup_terms_notice
  end

  def test_notice_renders_continue_notice_when_live_terms_are_pending
    pending = [Object.new]
    stub_tnc(pending: pending)
    view = view_with_tnc_helpers

    html = view.recording_studio_user_signup_terms_notice

    assert_equal({ actor: :actor, root: :root, pending: pending }, view.last_notice)
    assert_equal "NOTICE", html
  end

  private

  def view_with_tnc_helpers
    view = View.new
    view.define_singleton_method(:recording_studio_terms_agree_actor) { :actor }
    view.define_singleton_method(:recording_studio_terms_signup_root) { :root }
    view.define_singleton_method(:recording_studio_terms_continue_notice) do |**kwargs|
      @last_notice = kwargs
      "NOTICE"
    end
    view.define_singleton_method(:last_notice) { @last_notice }
    view
  end

  def stub_tnc(pending:)
    tnc = Module.new
    tnc.define_singleton_method(:pending_published_list) { |*_args, **_kwargs| pending }
    Object.const_set(:RecordingStudioTermsAndConditions, tnc)
  end

  def remove_tnc_constant!
    return unless Object.const_defined?(:RecordingStudioTermsAndConditions, false)

    Object.send(:remove_const, :RecordingStudioTermsAndConditions)
  end
end
