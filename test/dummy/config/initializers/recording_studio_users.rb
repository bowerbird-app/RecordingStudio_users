# frozen_string_literal: true

RecordingStudioUsers.configure do |config|
  config.user_class_name = "User"
  config.layout = "flat_pack_sidebar"
  config.current_actor = lambda do |controller: nil, **|
    controller&.send(:current_user) || Current.actor
  end
  config.current_impersonator = lambda do |controller: nil, **|
    if controller&.respond_to?(:current_impersonator, true)
      controller.send(:current_impersonator)
    else
      Current.impersonator
    end
  end
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
  config.access_actor_types = [ "User" ]
end
