# frozen_string_literal: true

module RecordingStudioUser
  # Public write and lookup helpers for the shared People root and Profile snapshots.
  module Directory
    PROFILE_ATTRIBUTE_KEYS = %i[first_name last_name time_zone additional_profile_attributes].freeze

    module_function

    def people_recordable
      People.first || People.create!
    end

    def people_root
      RecordingStudio.root_recording_for(people_recordable)
    end

    def profile_for(user)
      profile_recording_for(user)&.recordable
    end

    def profile_recording_for(user)
      return if user.blank? || !user.respond_to?(:id) || user.id.blank?

      RecordingStudio::Recording.find_by(
        recordable_type: Profile.name,
        recordable_id: Profile.where(user_id: user.id).select(:id),
        trashed_at: nil
      )
    end

    def create_user!(email:, password:, password_confirmation: nil, actor: nil, **attributes)
      profile_attrs = attributes.extract!(*PROFILE_ATTRIBUTE_KEYS)
      confirmation = password_confirmation.presence || password
      user = nil
      ActiveRecord::Base.transaction do
        user = create_devise_user!(email, password, confirmation, attributes)
        record_profile!(user, actor: actor, **profile_attrs)
      end
      user
    end

    def record_profile!(user, actor: nil, **profile_attrs)
      extras = filtered_additional_profile_attributes(profile_attrs[:additional_profile_attributes])
      assignment = profile_assignment(user, profile_attrs.merge(additional_profile_attributes: extras))
      recording = nil

      ActiveRecord::Base.transaction do
        recording = write_profile_recording(user, actor, assignment)
        bootstrap_profile_owner!(user, recording) unless ProfileAccess.authorized?(user, recording, role: :admin)
      end

      recording
    end

    def filtered_additional_profile_attributes(value)
      extras = (value.presence || {}).stringify_keys
      extras = extras.except(*Configuration::PROTECTED_PROFILE_ATTRIBUTES)
      extras.slice(*RecordingStudioUser.config.additional_profile_attributes.map(&:to_s))
    end

    def create_devise_user!(email, password, password_confirmation, attributes)
      RecordingStudioUser.config.user_class.create!(
        email: email,
        password: password,
        password_confirmation: password_confirmation,
        **attributes
      )
    end

    def write_profile_recording(user, actor, assignment)
      recording = profile_recording_for(user)
      if recording
        people_root.revise(recording, actor: actor, &assignment)
      else
        people_root.record(Profile, actor: actor, &assignment)
      end
    end

    def bootstrap_profile_owner!(user, recording)
      result = RecordingStudioAccessible.bootstrap_owner_access!(
        recording: recording,
        actor: user
      )
      raise result.error if result.failure?

      result.value
    end

    def profile_assignment(user, attrs)
      lambda do |profile|
        profile.user_id = user.id
        profile.first_name = attrs[:first_name]
        profile.last_name = attrs[:last_name]
        profile.time_zone = attrs[:time_zone].presence || "UTC"
        profile.additional_profile_attributes = attrs[:additional_profile_attributes] || {}
      end
    end
  end
end
