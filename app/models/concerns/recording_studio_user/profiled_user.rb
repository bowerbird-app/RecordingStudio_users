# frozen_string_literal: true

module RecordingStudioUser
  module ProfiledUser
    extend ActiveSupport::Concern

    included do
      validates :first_name, :last_name, :time_zone, presence: true
      validates :time_zone, inclusion: { in: ->(_record) { ActiveSupport::TimeZone.all.map(&:name) } }
    end

    def display_name
      RecordingStudioUser.display_name_for(self)
    end
  end
end
