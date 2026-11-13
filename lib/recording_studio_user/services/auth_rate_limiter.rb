# frozen_string_literal: true

require "recording_studio_cache"

module RecordingStudioUser
  module Services
    # Password sign-in and reset limits over {RecordingStudioCache::RateLimiter}.
    #
    # The email bucket is {OtpRateLimiter.email_key}: an HMAC-SHA256 of the
    # normalized address, so a cache dump does not list who tried. The IP
    # bucket is the request address. Every bucket is read before any of them
    # is incremented. A block on one key does not consume the others.
    #
    # Counters live on +Rails.cache+ and have to be shared by every app
    # process. Use Redis or Memcached. A memory store or a null store cannot
    # do that. {warn_unless_shared_store!} logs a warning at boot when the
    # store is one of those.
    class AuthRateLimiter
      STORAGE_KEY_PREFIX = "recording_studio_user:auth:rl"

      ACTIONS = {
        sign_in: {
          email_limit: :password_sign_in_email_limit,
          ip_limit: :password_sign_in_ip_limit,
          period: :password_sign_in_period
        },
        reset: {
          email_limit: :password_reset_email_limit,
          ip_limit: :password_reset_ip_limit,
          period: :password_reset_period
        }
      }.freeze

      def self.allow!(action:, email:, ip:)
        buckets = buckets_for(action, email, ip)
        return if buckets.empty?
        raise RateLimited, action if buckets.any? { |bucket| blocked?(bucket) }

        buckets.each { |bucket| consume!(action, bucket) }
      end

      def self.warn_unless_shared_store!
        return unless unshared_cache_store?

        Rails.logger.warn(
          "RecordingStudioUser password sign-in and reset limits need a shared, atomic " \
          "cache store (Redis or Memcached). #{Rails.cache.class.name} cannot enforce " \
          "them across processes."
        )
      end

      class RateLimited < StandardError
        attr_reader :action

        def initialize(action)
          @action = action
          super("rate limited")
        end
      end

      def self.buckets_for(action, email, ip)
        spec = ACTIONS.fetch(action)
        config = RecordingStudioUser.config
        period = config.public_send(spec[:period])
        [
          email_bucket(action, email, config.public_send(spec[:email_limit]), period),
          ip_bucket(action, ip, config.public_send(spec[:ip_limit]), period)
        ].compact
      end
      private_class_method :buckets_for

      def self.email_bucket(action, email, limit, period)
        normalized = OtpRateLimiter.normalize_email(email)
        return if normalized.blank?

        bucket(action, :email, OtpRateLimiter.email_key(normalized), limit, period)
      end
      private_class_method :email_bucket

      def self.ip_bucket(action, ip, limit, period)
        return if ip.blank?

        bucket(action, :ip, ip.to_s, limit, period)
      end
      private_class_method :ip_bucket

      def self.bucket(action, kind, identity, limit, period)
        { key: "#{STORAGE_KEY_PREFIX}:#{action}:#{kind}:#{identity}", limit: limit, period: period }
      end
      private_class_method :bucket

      def self.blocked?(bucket)
        value = Rails.cache.read(bucket[:key])
        value.is_a?(Numeric) && value >= bucket[:limit]
      end
      private_class_method :blocked?

      def self.consume!(action, bucket)
        result = RecordingStudioCache::RateLimiter.new(
          storage_key: bucket[:key],
          limit: bucket[:limit],
          period: bucket[:period],
          backend: :rails_cache,
          strategy: :ttl,
          store: Rails.cache,
          fail_closed: true
        ).throttle
        raise RateLimited, action if result.blocked?
      end
      private_class_method :consume!

      def self.unshared_cache_store?
        store = Rails.cache
        store.is_a?(ActiveSupport::Cache::MemoryStore) || store.is_a?(ActiveSupport::Cache::NullStore)
      end
      private_class_method :unshared_cache_store?
    end
  end
end
