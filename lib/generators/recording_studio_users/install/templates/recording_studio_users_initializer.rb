# frozen_string_literal: true

RecordingStudioUsers.configure do |config|
  config.user_class_name = "<%= options[:user_class] %>"
  config.current_actor = ->(controller:) { controller.send(:current_user) if controller.respond_to?(:current_user, true) }
  config.current_impersonator = lambda do |controller:|
    controller.send(:current_impersonator) if controller.respond_to?(:current_impersonator, true)
  end

  # Required: return a persisted system actor used for registration and backfill.
  config.provisioning_actor = lambda do |user: nil|
    # SystemActor.find_by(key: "recording-studio-users")
  end

  config.public_registration = true
  config.profile_fields = %i[display_name biography locale time_zone]

  # Defaults are self-only and fail closed. Broaden them explicitly when needed.
  config.identity_visibility_policy = ->(user:, actor:, **) { actor.present? && actor == user }
  config.email_visibility_policy = ->(user:, actor:, **) { actor.present? && actor == user }
  config.profile_visibility_policy = ->(user:, actor:, **) { actor.present? && actor == user }
  config.profile_edit_policy = ->(user:, actor:, **) { actor.present? && actor == user }
  config.stored_avatar_delivery_policy = ->(user:, actor:, **) { actor.present? && actor == user }

  config.user_label = ->(user:, **) { user.respond_to?(:name) ? user.name : nil }
  config.search_scope = ->(**) { <%= options[:user_class] %>.all }
  config.search_authorizer = ->(**) { false }
end
