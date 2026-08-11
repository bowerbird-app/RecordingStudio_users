# frozen_string_literal: true

module RecordingStudioUser
  class User < ActiveRecord::Base
    self.table_name = "users"

    devise :database_authenticatable, :recoverable, :rememberable, :validatable

    validates :first_name, :last_name, :time_zone, presence: true
    validate :time_zone_must_be_valid

    def full_name
      [first_name, last_name].compact_blank.join(" ")
    end

    def display_name
      full_name.presence || email.presence || "User"
    end

    private

    def time_zone_must_be_valid
      return if time_zone.blank? || ActiveSupport::TimeZone[time_zone].present?

      errors.add(:time_zone, "is not a valid Rails time zone")
    end
  end
end
