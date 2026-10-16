# frozen_string_literal: true

Rails.application.config.after_initialize do
  oauth_migrate = RecordingStudioOauth::Engine.root.join("db/migrate").cleanpath
  Rails.application.config.paths["db/migrate"].to_ary.delete_if do |path|
    Pathname.new(path).cleanpath == oauth_migrate
  end
end
