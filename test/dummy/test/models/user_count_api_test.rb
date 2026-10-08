# frozen_string_literal: true

require "test_helper"

class UserCountApiTest < ActiveSupport::TestCase
  class AllowView
    def self.call(_context, role)
      role == :view
    end
  end

  setup do
    @previous = RecordingStudioUser::Api::Access.method(:authorized_on_admin_root?)
    RecordingStudioUser::Api::Access.define_singleton_method(:authorized_on_admin_root?) do |_context, role|
      role == :view
    end
  end

  teardown do
    RecordingStudioUser::Api::Access.singleton_class.send(:define_method, :authorized_on_admin_root?, @previous)
  end

  test "user_count uses the configured user class count" do
    before = RecordingStudioUser.config.user_class.count
    assert_equal User.count, before
    assert_equal({ count: before }, RecordingStudioUser::Api::UserCount.call(Object.new))

    User.create!(
      email: "user-count-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      registered_with: "password"
    )

    after = RecordingStudioUser.config.user_class.count
    assert_equal before + 1, after
    assert_equal({ count: after }, RecordingStudioUser::Api::UserCount.call(Object.new))
  end
end
