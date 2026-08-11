# frozen_string_literal: true

module RecordingStudioUser
  module Admin
    class UsersScreen < RecordingStudioAdmin::Screen
      key "users"
      icon :user_group
      title "Users"
      subtitle "Sitewide user directory and account growth"
      blast_radius :site

      query { |_context| RecordingStudioUser.user_class.order(created_at: :desc) }

      summary do
        label "Total users"
        change_good_when :up
        hide_change
        hide_period
      end

      chart do
        title "Total users over time"
        type :line
        series do |context|
          relation = context.query_result.relation.except(:order)
          total = 0
          points = relation.group(Arel.sql("DATE(created_at)")).order(Arel.sql("DATE(created_at)")).count.map do |date, count|
            total += count
            { x: date.to_date.iso8601, y: total }
          end

          [{ name: "Total users", data: points }]
        end
      end

      table do
        title "Users"
        column :name, sortable: false, value: ->(user, _context) { user.display_name }
        column :email
        column :time_zone, title: "Time zone"
        column :created_at, title: "Created at"
        default_sort :created_at, direction: :desc
        paginate per_page: 25
      end
    end
  end
end
