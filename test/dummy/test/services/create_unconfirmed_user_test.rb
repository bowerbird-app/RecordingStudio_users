# frozen_string_literal: true

require "test_helper"

class CreateUnconfirmedUserTest < ActiveSupport::TestCase
  module SkipValidation
    def valid?(...)
      return true if Thread.current[:skip_user_validation]

      super
    end
  end

  setup do
    User.prepend(SkipValidation) unless User < SkipValidation
  end

  test "create_unconfirmed_user returns the existing row when the insert loses" do
    email = "lost-insert-#{SecureRandom.hex(4)}@example.com"
    existing = RecordingStudioUser.create_unconfirmed_user!(email: email)
    original_new = User.method(:new)

    User.define_singleton_method(:new) do |*args, **kwargs|
      record = original_new.call(*args, **kwargs)
      record.define_singleton_method(:save!) { raise ActiveRecord::RecordNotUnique }
      record
    end

    found = RecordingStudioUser.create_unconfirmed_user!(email: " #{email.upcase} ")

    assert_equal existing.id, found.id
    assert_equal 1, User.where(email: email).count
  ensure
    if original_new
      User.define_singleton_method(:new) do |*args, **kwargs, &block|
        original_new.call(*args, **kwargs, &block)
      end
    end
  end

  test "concurrent create_unconfirmed_user returns one user" do
    email = "race-#{SecureRandom.hex(4)}@example.com"
    users = Queue.new
    errors = Queue.new

    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Thread.current[:skip_user_validation] = true
          users << RecordingStudioUser.create_unconfirmed_user!(email: email)
        end
      rescue StandardError => error
        errors << error
      end
    end
    threads.each(&:join)

    assert_empty drain(errors)
    found = drain(users)
    assert_equal 1, User.where(email: email).count
    assert_equal [ found.first.id ], found.map(&:id).uniq
  end

  private

  def drain(queue)
    items = []
    items << queue.pop(true) until queue.empty?
    items
  rescue ThreadError
    items
  end
end
