# frozen_string_literal: true

module RecordingStudioUser
  class Identity < ApplicationRecord
    self.table_name = "recording_studio_user_identities"

    belongs_to :user, class_name: RecordingStudioUser.config.user_class_name, inverse_of: :identities

    # An identity for a provider the host no longer configures cannot sign anyone
    # in: no strategy is registered and no callback route exists.
    scope :for_configured_providers, lambda {
      where(provider: RecordingStudioUser.config.omniauth_provider_names.map(&:to_s))
    }

    validates :provider, presence: true
    validates :uid, presence: true
    validates :uid, uniqueness: { scope: :provider }
    validates :provider, uniqueness: { scope: :user_id }
  end
end
