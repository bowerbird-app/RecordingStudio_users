# frozen_string_literal: true

require "recording_studio_admin"
require "recording_studio_metrics"

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
      widget "widgets.otp_challenges.failed_over_time"
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

    FailedOtpChallengesWidget = RecordingStudioAdmin::Widget.new(
      "widgets.otp_challenges.failed_over_time",
      blast_radius: :site
    ) do
      type :chart
      title "Locked codes"
      info "How many one-time codes locked after too many wrong tries. Open Users if this line jumps."
      chart_type :area
      series { |context| RecordingStudioUser::Admin.failed_otp_chart_series(context) }
      chart_options { { height: 220 } }
      link_to { |context| context.admin_screen_path("recording_studio_users") }
      change_good_when :down
      hide_change
      hide_period
    end

    class << self
      FAILED_OTP_METRIC = "otp_challenges.failed_over_time"
      FAILED_OTP_INTERVALS = %i[day week month year].freeze

      def register!
        RecordingStudioAdmin.register_section(UsersSection)
        RecordingStudioAdmin.register_screen(UsersScreen)
        RecordingStudioAdmin.register_widget(TotalUsersWidget)
        RecordingStudioAdmin.register_widget(FailedOtpChallengesWidget)
      end

      def user_creation_series(users)
        users.reorder(nil)
             .group("DATE(created_at)")
             .order(Arel.sql("DATE(created_at)"))
             .count
             .map { |date, count| { x: date.to_s, y: count } }
      end

      def failed_otp_chart_series(context)
        range = context.widget_time_range
        interval = context.widget_group_by(default: :day)
        params = { site_authorized: true, scope: :site }
        params[:interval] = interval if FAILED_OTP_INTERVALS.include?(interval)
        if range.respond_to?(:begin) && range.respond_to?(:end) && range.begin && range.end
          params[:start_at] = range.begin
          params[:end_at] = range.end
        end

        RecordingStudioMetrics::Admin.chart_series(
          FAILED_OTP_METRIC,
          admin_context: context,
          **params
        )
      end
    end
  end
end
