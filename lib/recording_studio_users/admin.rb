# frozen_string_literal: true

require "recording_studio_admin"

module RecordingStudioUsers
  module Admin
    class UsersSection < RecordingStudioAdmin::Section
      key "users"
      title "Users"
      icon :user_group
      blast_radius :site
      link :users, text: "View users", url: ->(context) { context.admin_screen_path("users") }
    end

    class UsersScreen < RecordingStudioAdmin::Screen
      key "users"
      title "Users"
      icon :user_group
      blast_radius :site
      query { |_context| RecordingStudioUsers.user_class.all }
      filter :date_range, field: :created_at, default: :last_30_days
      filter :group_by, values: %i[day week month year], default: :day

      summary do
        label "Users created"
        value ->(context) { context.query_result.relation.except(:order).count }
        hide_change
      end

      chart do
        title "Users created over time"
        type :line
        series do |context|
          [{ name: "Users", data: RecordingStudioUsers::Admin.date_series(context) }]
        end
      end

      table do
        title "Users"
        column :identity, title: "User", sortable: false, value: lambda { |user, context|
          RecordingStudioUsers::Admin.render_identity(user, context)
        }
        column :email, value: lambda { |user, context|
          RecordingStudioUsers.email_visible?(user, actor: context.current_actor, context:) ? user.email : nil
        }
        column :created_at, title: "Created", display: :timestamp
        default_sort :created_at, direction: :desc
        paginate per_page: 25
      end
    end

    class << self
      def register!
        RecordingStudioAdmin.register_section(UsersSection)
        RecordingStudioAdmin.register_screen(UsersScreen)
      end

      def date_series(context)
        bucket = context.filter_value(:group_by).to_s
        bucket = "day" unless %w[day week month year].include?(bucket)
        expression = Arel.sql("DATE_TRUNC('#{bucket}', created_at)")
        context.query_result.relation.except(:order).group(expression).order(expression).count.map do |date, count|
          { x: date.iso8601, y: count }
        end
      end

      def render_identity(user, context)
        RecordingStudioUsers.prepare_admin_rows(context)
        view_context = context.view_context || context.controller&.view_context
        return RecordingStudioUsers.display_name(user, context:) unless view_context

        avatar = view_context.render(
          RecordingStudioUsers::AvatarComponent.new(
            user:,
            size: :small,
            context:
          )
        )
        name = view_context.content_tag(
          :span,
          RecordingStudioUsers.display_name(user, context:),
          class: "font-medium"
        )
        view_context.safe_join([avatar, name], " ")
      end
    end
  end
end
