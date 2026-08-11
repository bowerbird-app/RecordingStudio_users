# frozen_string_literal: true

module DummyAdmin
  class RootSection < RecordingStudioAdmin::Section
    key "root"
    icon :settings
    title "Admin"
    subtitle "Site administration"
    blast_radius :site

    link :users,
         text: "Users admin",
         url: ->(context) { context.admin_screen_path("users") },
         style: :primary
  end

  module_function

  def register!
    RecordingStudioAdmin.register_section(RootSection)
  end
end
