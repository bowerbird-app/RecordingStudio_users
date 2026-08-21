# frozen_string_literal: true

require "recording_studio_admin"

module RecordingStudioUser
  module Admin
    class UsersSection < RecordingStudioAdmin::Section
      key "users"
      icon :user_group
      title "Users"
      subtitle "Review sitewide user accounts"
      blast_radius :site

      link :users,
           text: "Users admin",
           url: ->(context) { context.admin_screen_path("recording_studio_users") },
           style: :secondary
      widget "widgets.users.total", view_variant: :compact
    end

    class UsersScreen < RecordingStudioAdmin::Screen
      key "recording_studio_users"
      icon :user_group
      title "Users"
      subtitle "Review sitewide user accounts"
      blast_radius :site
      query { |_context| RecordingStudioUser.config.user_class.order(created_at: :desc) }
      filter :date_range, field: :created_at, default: :last_30_days
      filter :group_by, values: %i[day week month], default: :day

      chart do
        title "Users over time"
        type :line
        series { |context| [{ name: "Users", data: RecordingStudioUser::Admin.user_creation_series(context.query_result.relation) }] }
      end

      table do
        column :display_name,
               title: "Name",
               sortable: false,
               value: ->(user, _context) { RecordingStudioUser.display_name_for(user) }
        column :email, title: "Email"
        column :time_zone, title: "Time zone"
        column :created_at, title: "Created at"
      end
      widget "widgets.users.total"
    end

    TotalUsersWidget = RecordingStudioAdmin::Widget.new("widgets.users.total", blast_radius: :site) do
      type :number
      title "Total users"
      value { |_context| RecordingStudioUser.config.user_class.count }
      link_to { |context| RecordingStudioUser.mounted_admin_path(context) }
      hide_change
      hide_period
    end

    class << self
      def register!
        RecordingStudioAdmin.register_section(UsersSection)
        RecordingStudioAdmin.register_screen(UsersScreen)
        RecordingStudioAdmin.register_widget(TotalUsersWidget)
      end

      def user_creation_series(users)
        users.reorder(nil)
             .group("DATE(created_at)")
             .order(Arel.sql("DATE(created_at)"))
             .count
             .map { |date, count| { x: date.to_s, y: count } }
      end
    end
  end
end
