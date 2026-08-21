# frozen_string_literal: true

RecordingStudioUsers.configure do |config|
  config.current_actor_resolver = ->(controller:) { controller.send(:current_user) }
  config.authentication_redirect = ->(controller:) { controller.main_app.new_user_session_path }
  config.after_role_switch_redirect = ->(controller:) { controller.main_app.root_path }
  config.layout = "application"
  config.mailer_sender = "users@example.com"
  config.root_scope_key = "workspaces"
  config.root_creator = ->(name:, **) { Workspace.create!(name: name) }
end
