# frozen_string_literal: true

module RecordingStudioNotificationsPush
  # Browser / device registration for FCM. This is a normal ActiveRecord table,
  # not a Recording Studio recordable.
  class Installation < ApplicationRecord
    self.table_name = "recording_studio_notifications_push_installations"

    belongs_to :recipient, polymorphic: true

    validates :firebase_installation_id, presence: true
    validates :firebase_installation_id,
              uniqueness: { scope: %i[recipient_type recipient_id], case_sensitive: true }

    scope :active, -> { where(disabled_at: nil) }
    scope :for_recipient, lambda { |recipient|
      where(recipient_type: recipient.class.base_class.name, recipient_id: recipient.id)
    }

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists
    def self.upsert!(recipient:, firebase_installation_id:, legacy_fcm_token: nil,
                     user_agent: nil, platform: nil, label: nil)
      raise ArgumentError, "recipient is required" if recipient.nil?

      fid = firebase_installation_id.to_s.strip
      raise ArgumentError, "firebase_installation_id is required" if fid.blank?

      record = find_or_initialize_by(
        recipient_type: recipient.class.base_class.name,
        recipient_id: recipient.id,
        firebase_installation_id: fid
      )

      record.recipient = recipient
      assign_optional_string!(record, :legacy_fcm_token, legacy_fcm_token)
      assign_optional_string!(record, :user_agent, user_agent)
      assign_optional_string!(record, :platform, platform)
      assign_optional_string!(record, :label, label)
      record.disabled_at = nil
      record.last_seen_at = Time.current
      record.save!
      record
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists

    def self.assign_optional_string!(record, attribute, value)
      record.public_send("#{attribute}=", value.to_s.presence) unless value.nil?
    end
    private_class_method :assign_optional_string!

    def delivery_token
      firebase_installation_id.to_s.presence || legacy_fcm_token.to_s.presence
    end

    def active?
      disabled_at.nil?
    end

    def disable!(reason: nil)
      _ = reason # reserved for future disable-reason audit rows
      return self if disabled_at.present?

      update!(disabled_at: Time.current)
      self
    end

    def touch_seen!
      update_columns(last_seen_at: Time.current, updated_at: Time.current)
    end

    def display_label
      candidate = label.to_s.strip
      return candidate if candidate.present? && !self.class.user_agent_like?(candidate)

      self.class.label_from_user_agent(user_agent) || platform.presence || "Browser"
    end

    def mobile?
      self.class.mobile_device?(user_agent: user_agent, platform: platform, label: label)
    end

    def list_icon
      mobile? ? :device_phone_mobile : :computer_desktop
    end

    def self.user_agent_like?(value)
      value.start_with?("Mozilla/") || value.length > 48
    end

    def self.label_from_user_agent(user_agent)
      agent = user_agent.to_s
      return if agent.blank?

      browser = browser_name_from_user_agent(agent)
      os = os_name_from_user_agent(agent)
      return unless browser && os

      "#{browser} on #{os}"
    end

    def self.mobile_device?(user_agent: nil, platform: nil, label: nil)
      haystack = [user_agent, platform, label].map { |value| value.to_s.downcase }.join(" ")
      return true if haystack.match?(/\b(iphone|ipod|ipad|android|ios|mobile)\b/)
      return true if haystack.match?(/\bon (iphone|ipad|android)\b/)

      false
    end

    def self.browser_name_from_user_agent(user_agent)
      return "Edge" if user_agent.match?(%r{Edg/})
      return "Chrome" if user_agent.match?(%r{Chrome/})
      return "Firefox" if user_agent.match?(%r{Firefox/})
      return "Safari" if user_agent.match?(%r{Safari/}) && !user_agent.match?(%r{Chrome/})

      "Browser"
    end

    def self.os_name_from_user_agent(user_agent)
      return "iPad" if user_agent.match?(/iPad/)
      return "iPhone" if user_agent.match?(/iPhone|iPod/)
      return "Mac" if user_agent.match?(/Mac OS X|Macintosh/)
      return "Windows" if user_agent.match?(/Windows/)
      return "Android" if user_agent.match?(/Android/)
      return "Linux" if user_agent.match?(/Linux/)

      "device"
    end
  end
end
