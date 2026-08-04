# frozen_string_literal: true

RecordingStudioUsers.configure do |config|
  config.user_class_name = "User"
  config.current_actor = ->(**) { Current.actor }
  config.current_impersonator = ->(**) { Current.impersonator }
  config.provisioning_actor = ->(user:, **) { user }
  config.identity_visibility_policy = ->(user:, actor:, **) { actor.present? && user.present? }
  config.email_visibility_policy = ->(user:, actor:, **) { actor == user }
  config.profile_visibility_policy = ->(user:, actor:, **) { actor == user }
  config.profile_edit_policy = ->(user:, actor:, **) { actor == user }
  config.stored_avatar_delivery_policy = ->(user:, actor:, **) { actor == user }
  config.search_scope = ->(**) { User.all }
  config.search_authorizer = ->(actor:, **) { actor.present? }
end

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = ["User"]
end
