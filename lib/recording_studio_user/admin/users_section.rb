# frozen_string_literal: true

module RecordingStudioUser
  module Admin
    class UsersSection < RecordingStudioAdmin::Section
      key "users"
      icon :user_group
      title "Users"
      subtitle "Sitewide user accounts and growth"
      blast_radius :site

      link :users,
           text: "View users",
           url: ->(context) { context.admin_screen_path("users") },
           style: :secondary

      widget "widgets.users.total",
             view_variant: :compact,
             link_to: ->(context) { context.admin_screen_path("users") },
             blast_radius: :site
    end
  end
end
