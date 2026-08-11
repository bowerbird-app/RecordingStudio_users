# frozen_string_literal: true

module RecordingStudioUser
  module Admin
    TotalUsersWidget = RecordingStudioAdmin::Widget.new("widgets.users.total") do
      type :number
      title "Total users"
      description "All site-level user accounts"
      value { |_context| RecordingStudioUser.user_class.count }
      hide_change
      hide_period
      blast_radius :site
      link_to { |context| context.admin_screen_path("users") }
      link_label "View users"
    end
  end
end
