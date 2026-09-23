# frozen_string_literal: true

require "test_helper"
require File.expand_path(
  "../app/controllers/concerns/recording_studio_user/auth/signup_terms_acceptance.rb",
  __dir__
)

class SignupTermsAcceptanceTest < Minitest::Test
  class Controller
    include RecordingStudioUser::Auth::SignupTermsAcceptance

    def accept(actor)
      accept_pending_terms_on_signup!(actor)
    end
  end

  def setup
    remove_tnc_constant!
  end

  def teardown
    remove_tnc_constant!
  end

  def test_acceptance_is_noop_without_tnc
    refute defined?(RecordingStudioTermsAndConditions)
    assert_nil Controller.new.accept(Object.new)
  end

  def test_acceptance_is_noop_without_an_actor
    stub_tnc

    assert_nil Controller.new.accept(nil)
    assert_empty RecordingStudioTermsAndConditions.accepted
  end

  def test_acceptance_is_noop_without_a_signup_root
    stub_tnc(root: nil)
    terms = Object.new

    assert_nil Controller.new.accept(Object.new)
    refute_includes RecordingStudioTermsAndConditions.accepted, terms
  end

  def test_accepts_pending_live_terms_with_continue_notice_provenance
    terms = Object.new
    stub_tnc(pending: [terms])
    actor = Object.new

    Controller.new.accept(actor)

    assert_equal(
      [[actor, terms, { "source" => "continue_notice" }]],
      RecordingStudioTermsAndConditions.accepted
    )
  end

  def test_not_live_does_not_raise
    stub_tnc(pending: [Object.new], raise_not_live: true)

    assert_nil Controller.new.accept(Object.new)
  end

  private

  def stub_tnc(pending: [], root: :root, raise_not_live: false)
    tnc = Module.new
    not_live = Class.new(StandardError)
    gate = Module.new
    gate.define_singleton_method(:root_for_signup) { |*_args, **_kwargs| root }
    accepted = []
    tnc.const_set(:NotLive, not_live)
    tnc.const_set(:Gate, gate)
    tnc.define_singleton_method(:pending_published_list) { |*_args, **_kwargs| pending }
    tnc.define_singleton_method(:accepted) { accepted }
    tnc.define_singleton_method(:accept!) do |actor, terms, provenance|
      raise not_live, "not live" if raise_not_live

      accepted << [actor, terms, provenance]
    end
    Object.const_set(:RecordingStudioTermsAndConditions, tnc)
  end

  def remove_tnc_constant!
    return unless Object.const_defined?(:RecordingStudioTermsAndConditions, false)

    Object.send(:remove_const, :RecordingStudioTermsAndConditions)
  end
end
