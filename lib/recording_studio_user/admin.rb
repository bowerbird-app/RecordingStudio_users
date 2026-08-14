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
         url: ->(_context) { RecordingStudioAdmin::Engine.routes.url_helpers.screen_path("recording_studio_users") },
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
               value: ->(user, _context) { RecordingStudioUser::Admin.display_name(user) }
        column :email, title: "Email"
        column :time_zone, title: "Time zone"
        column :created_at, title: "Created at"
         action :view_user,
           text: "View user",
           icon: "eye",
           url: ->(user, _context) { RecordingStudioUser::Engine.routes.url_helpers.admin_user_path(user) }
      end
      widget "widgets.users.total"
    end

    TotalUsersWidget = RecordingStudioAdmin::Widget.new("widgets.users.total", blast_radius: :site) do
      type :number
      title "Total users"
      value { |_context| RecordingStudioUser.config.user_class.count }
      link_to { |_context| RecordingStudioAdmin::Engine.routes.url_helpers.screen_path("recording_studio_users") }
      hide_change
      hide_period
    end

    class << self
      def register!
        RecordingStudioAdmin.register_section(UsersSection)
        RecordingStudioAdmin.register_screen(UsersScreen)
        RecordingStudioAdmin.register_widget(TotalUsersWidget)
      end

      def display_name(user)
        value = user.full_name if user.respond_to?(:full_name)
        value = [user.try(:first_name), user.try(:last_name)].compact_blank.join(" ") if value.blank?
        value.presence || user.try(:email).presence || I18n.t("recording_studio_user.profile.unnamed_user",
                                                              default: "User")
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
